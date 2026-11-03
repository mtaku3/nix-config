{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.openmausbot;
  inherit (cfg) user;
  home = "/var/lib/${user}";
  prefix = "${home}/.local";
  bin = "${prefix}/bin/openmausbot";

  # OpenMausBot's server as its VPS guide sets it up (docs/deploy-vps.md):
  # an unprivileged user of its own runs setup, the engine CLIs and the
  # service; the release is npm-installed into that user's ~/.local; and a
  # systemd unit runs `openmausbot serve` from there. The data lives in
  # ~/.openmausbot and the engines' logins in their own dot directories, so
  # the whole home persists. The release is not pinned: the guide's update
  # (stop, npm install a version, start) runs daily with the latest one.
  #
  # The bots run as this user on this machine, through its `claude` CLI, so
  # they see everything the user can. Give them credentials of their own.
  npm = "${cfg.nodejs}/bin/npm";
  install = pkg: "${npm} install --global --prefix ${prefix} ${pkg}";

  # Run as root: the update stops and starts the service around the install.
  update = pkgs.writeShellScript "openmausbot-update" ''
    set -euo pipefail
    latest=$(${pkgs.util-linux}/bin/runuser -u ${user} -- ${npm} view openmausbot version)
    current=$(${pkgs.jq}/bin/jq -r .version ${prefix}/lib/node_modules/openmausbot/package.json 2>/dev/null || true)
    if [ "$latest" = "$current" ]; then
      echo "openmausbot $current is the latest"
      exit 0
    fi
    echo "updating openmausbot $current -> $latest"
    systemctl stop openmausbot.service
    trap 'systemctl start openmausbot.service' EXIT
    ${pkgs.util-linux}/bin/runuser -u ${user} -- ${install "openmausbot@${"$"}latest"}
  '';

  servicePath =
    [cfg.nodejs pkgs.git pkgs.bashInteractive pkgs.coreutils]
    ++ [
      "${prefix}"
      "/run/wrappers"
      "/etc/profiles/per-user/${user}"
      "/run/current-system/sw"
    ];
in {
  options.capybara.app.server.openmausbot = with types; {
    enable = mkBoolOpt false "Whether to run an OpenMausBot server";

    user = mkOpt str "openmausbot" ''
      The user that runs OpenMausBot and its bots, made for it with its home in
      /var/lib/<user>.
    '';

    nodejs = mkOpt package pkgs.nodejs_24 "Node.js (24 or newer) for the server and npm";

    args = mkOpt (listOf str) ["--tunnel" "--no-pair"] ''
      Arguments of `openmausbot serve`. The default reaches it through the
      project's tunnel at the address `openmausbot login` reserved.
    '';

    packages = mkOpt (listOf package) [] ''
      Commands the bots can run, besides those of the system.
    '';

    environment = mkOpt (attrsOf str) {} ''
      Environment of the server, e.g. `OMB_ANTHROPIC_API_URL` for an LLM
      gateway. OpenMausBot ignores `ANTHROPIC_*` from its environment.
    '';

    environmentFiles = mkOpt (listOf str) [] ''
      Files of `KEY=value` lines added to the environment, for secrets such as
      `OMB_ANTHROPIC_API_KEY`; typically agenix secrets.
    '';
  };

  config = mkIf cfg.enable {
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      inherit home;
      createHome = true;
      shell = pkgs.bashInteractive;
      packages = [cfg.nodejs pkgs.git] ++ cfg.packages;
    };
    users.groups.${user} = {};

    # The engine CLIs npm installs ship prebuilt binaries.
    programs.nix-ld.enable = true;

    # The CLI, for `sudo -iu openmausbot openmausbot login|pair|sessions|status`.
    environment.systemPackages = [
      (pkgs.runCommand "openmausbot-command" {} ''
        mkdir -p $out/bin
        ln -s ${bin} $out/bin/openmausbot
      '')
    ];

    # The first install: the release and the Claude engine, as the guide
    # installs them. Claude Code updates itself in the same prefix.
    systemd.services.openmausbot-install = {
      description = "Install OpenMausBot and its Claude engine";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      before = ["openmausbot.service"];
      requiredBy = ["openmausbot.service"];
      unitConfig.ConditionPathExists = "!${bin}";
      # npm runs install scripts with sh.
      path = [cfg.nodejs pkgs.git pkgs.bash];
      environment.HOME = home;
      serviceConfig = {
        Type = "oneshot";
        User = user;
        WorkingDirectory = home;
        ExecStart = [
          (install "openmausbot@latest")
          (install "@anthropic-ai/claude-code")
        ];
        TimeoutStartSec = "15min";
      };
    };

    # The guide's unit (docs/deploy-vps.md, Keep it running).
    systemd.services.openmausbot = {
      description = "OpenMausBot server";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      path = servicePath;
      environment =
        {
          # Not upstream's default (owner): a session-less request from this
          # machine, which includes every bot's shell, may then change
          # settings, keys, MCP servers or webhooks. With service it needs a
          # paired session, as from elsewhere (docs/self-hosting.md, Loopback
          # trust). `openmausbot pair` and `sessions` are refused too: pair
          # from Settings > Remote access instead.
          OMB_LOOPBACK_TRUST = "service";
        }
        // cfg.environment
        // {HOME = home;};
      # The tunnel's address is reserved by `openmausbot login`, which needs an
      # emailed code: start the service after it.
      unitConfig.ConditionPathExists = mkIf (elem "--tunnel" cfg.args) "${home}/.openmausbot/tunnel-account.json";
      serviceConfig = {
        User = user;
        WorkingDirectory = home;
        ExecStart = escapeShellArgs ([bin "serve"] ++ cfg.args);
        Restart = "always";
        RestartSec = 5;
        EnvironmentFile = cfg.environmentFiles;

        # Not upstream: what the bots can read beyond the user's own files.
        # The other users' homes, the network filesystems that are mounted
        # with allow_other under /mnt, and the other users' processes.
        ProtectHome = true;
        TemporaryFileSystem = "/mnt:ro";
        ProtectProc = "invisible";
      };
    };

    # The guide's update, with the latest release.
    systemd.services.openmausbot-update = {
      description = "Update OpenMausBot";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [cfg.nodejs pkgs.git pkgs.bash config.systemd.package];
      environment.HOME = home;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = update;
        TimeoutStartSec = "15min";
      };
    };

    systemd.timers.openmausbot-update = {
      description = "Update OpenMausBot daily";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* 04:00";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
    };

    capybara.impermanence.directories = [
      {
        directory = home;
        inherit user;
        group = user;
        mode = "0700";
      }
    ];
  };
}
