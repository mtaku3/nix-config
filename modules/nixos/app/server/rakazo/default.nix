{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.rakazo;
  dir = cfg.dataDir;

  # Rakazo's self-hosting with its published images (docs/self-host.md):
  # install-images.sh, run in an empty folder, downloads the Compose file,
  # creates .env with random secrets, pulls the images and starts the stack.
  # Rerun, it keeps .env and moves the stack to the newest Compose file and
  # images of its tag, which is how a deployment upgrades. The script runs
  # unmodified from the data directory; this module only gives it its
  # settings and runs it at boot and daily.
  installer = "https://raw.githubusercontent.com/elie222/rakazo/main/infra/compose/install-images.sh";

  # KEY=value lines that replace or add the same keys in .env, the only place
  # Compose reads settings from. Secrets the installer generated stay as they
  # are.
  settingsFile = pkgs.writeText "rakazo-settings.env" (concatStrings (mapAttrsToList (key: value: "${key}=${value}\n") cfg.settings));

  mergeEnv = pkgs.writeShellScript "rakazo-merge-env" ''
    set -euo pipefail
    umask 077
    overrides=$(mktemp)
    trap 'rm -f "$overrides" .env.merge' EXIT
    cat ${settingsFile} ${escapeShellArgs cfg.environmentFiles} >"$overrides"
    awk '
      function key(line) { return substr(line, 1, index(line, "=") - 1) }
      FNR == NR {
        if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
          k = key($0)
          if (!(k in value)) order[++n] = k
          value[k] = $0
        }
        next
      }
      $0 ~ /^[A-Za-z_][A-Za-z0-9_]*=/ && (key($0) in value) {
        k = key($0)
        if (!(k in done)) print value[k]
        done[k] = 1
        next
      }
      { print }
      END { for (i = 1; i <= n; i++) if (!(order[i] in done)) print value[order[i]] }
    ' "$overrides" .env >.env.merge
    mv .env.merge .env
  '';

  # Starts or upgrades the stack. The first run only prepares .env, so that the
  # stack starts with the settings below.
  deploy = pkgs.writeShellScript "rakazo-deploy" ''
    set -euo pipefail
    cd ${dir}
    curl -fsSLO ${installer}
    [ -e .env ] || bash install-images.sh --prepare-only
    ${mergeEnv}
    bash install-images.sh
  '';

  compose = "docker compose --env-file .env -f docker-compose.images.yml $([ -f docker-compose.override.yml ] && echo -f docker-compose.override.yml)";

  path = with pkgs; [
    bash
    coreutils
    curl
    config.virtualisation.docker.package
    findutils
    gawk
    gnugrep
    gnused
    iproute2
    iptables
    openssl
    systemd
  ];
in {
  options.capybara.app.server.rakazo = with types; {
    enable = mkBoolOpt false "Whether to run a self-hosted Rakazo with its published images";

    dataDir = mkOpt str "/var/lib/rakazo" ''
      Where the installer keeps the Compose file and .env, whose generated
      secrets (ENCRYPTION_KEY among them) the stored data needs. Postgres and
      the bot homes are Docker volumes.
    '';

    publicUrl = mkOpt str "http://127.0.0.1:5173" ''
      The HTTPS origin the browser and the apps use, for a TLS proxy in front
      of the web port. The API is reached through it, never directly.
    '';

    bind = mkOpt str "127.0.0.1" ''
      Host address the web port (5173) is published on, for the TLS proxy to
      reach. Starting waits until the host has it.
    '';

    settings = mkOpt (attrsOf str) {} ''
      .env settings besides the URLs and bind address above
      (docs/self-host-configuration.md). Not for secrets: they go in the store.
    '';

    environmentFiles = mkOpt (listOf str) [] ''
      Files of KEY=value lines merged into .env like `settings`, for secrets
      such as OIDC_CLIENT_SECRET; typically agenix secrets.
    '';
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = "capybara.app.server.rakazo needs rootful Docker (capybara.app.dev.docker.mode = \"rootful\")";
      }
    ];

    capybara.app.server.rakazo.settings = let
      host = head (splitString "/" (removePrefix "http://" (removePrefix "https://" cfg.publicUrl)));
    in {
      BETTER_AUTH_URL = cfg.publicUrl;
      WEB_ORIGIN = cfg.publicUrl;
      API_URL = cfg.publicUrl;
      RAKAZO_HOST = mkDefault (head (splitString ":" host));
      RAKAZO_WEB_BIND = cfg.bind;
      # Stable releases; the installer's default, edge, follows main.
      RAKAZO_IMAGE_TAG = mkDefault "latest";
      RAKAZO_COMPUTER_IMAGE_TAG = mkDefault "latest";
      # Accounts are made on the server (docs/self-host-accounts.md).
      SIGNUPS_ENABLED = mkDefault "false";
    };

    # The installer's first full run installs the computers' egress rules
    # (restrict-computer-egress.sh) and makes them persist with a unit in
    # /etc/systemd/system and a copy of the script in /usr/local/sbin. Those
    # writes go to a private tmpfs here, and the unit below applies the rules
    # at boot instead, from the copy the installer leaves in the data directory.
    systemd.tmpfiles.rules = [
      "d ${dir} 0700 root root -"
      "d /usr/local/sbin 0755 root root -"
    ];

    systemd.services.rakazo = {
      description = "Rakazo (Docker Compose, published images)";
      wants = ["network-online.target" "rakazo-computer-egress.service"];
      after = ["network-online.target" "docker.service" "rakazo-computer-egress.service"];
      requires = ["docker.service"];
      wantedBy = ["multi-user.target"];
      inherit path;
      environment.SYSTEMCTL_INSTALL_CLIENT_SIDE = "1";
      # A changed setting is applied by running the installer again, which
      # recreates only what changed.
      reloadIfChanged = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = mkIf (cfg.bind != "0.0.0.0") (pkgs.writeShellScript "rakazo-wait-bind" ''
          for _ in $(seq 120); do
            ip -o addr | grep -qF " ${cfg.bind}/" && exit 0
            sleep 1
          done
          echo "${cfg.bind} is not an address of this host" >&2
          exit 1
        '');
        ExecStart = deploy;
        ExecReload = deploy;
        ExecStop = pkgs.writeShellScript "rakazo-down" ''
          cd ${dir}
          ${compose} down
        '';
        TimeoutStartSec = "30min";
        # The worker finishes the jobs it is running before it stops.
        TimeoutStopSec = "50min";
        TemporaryFileSystem = ["/etc/systemd/system" "/usr/local/sbin"];
      };
    };

    systemd.services.rakazo-computer-egress = {
      description = "Restrict Rakazo bot-computer egress (rakazo-c* bridges)";
      wants = ["docker.service"];
      after = ["docker.service"];
      unitConfig.ConditionPathExists = "${dir}/restrict-computer-egress.sh";
      path = [pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.iptables];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash ${dir}/restrict-computer-egress.sh --apply";
      };
    };

    systemd.services.rakazo-update = {
      description = "Upgrade Rakazo";
      after = ["rakazo.service"];
      requisite = ["rakazo.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.systemd.package}/bin/systemctl reload rakazo.service";
      };
    };

    systemd.timers.rakazo-update = {
      description = "Upgrade Rakazo daily";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    capybara.impermanence.directories = [dir];
  };
}
