{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.openmausbot;
  inherit (cfg) user;
  home = "/var/lib/${user}";
  prefix = "${home}/.local";

  # OpenMausBot's server as its VPS guide sets it up (docs/deploy-vps.md):
  # an unprivileged user of its own runs setup, the engine CLIs and the
  # service, and a systemd unit runs `openmausbot serve`. The data lives in
  # ~/.openmausbot and the engines' logins in their own dot directories, so
  # the whole home persists. Not the guide: the server is the pinned, patched
  # package of the openmausbot flake input instead of an npm release, so an
  # update is a version bump there followed by a rebuild here.
  #
  # The bots run as this user on this machine, through its `claude` CLI, so
  # they see everything the user can. Give them credentials of their own.
  npm = "${cfg.nodejs}/bin/npm";
  install = pkg: "${npm} install --global --prefix ${prefix} ${pkg}";

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

    package = mkOpt package inputs.openmausbot.packages.${pkgs.stdenv.hostPlatform.system}.openmausbot ''
      The OpenMausBot server: by default the patched build of the openmausbot
      flake input (mtaku3/openmausbot).
    '';

    user = mkOpt str "openmausbot" ''
      The user that runs OpenMausBot and its bots, made for it with its home in
      /var/lib/<user>.
    '';

    nodejs = mkOpt package pkgs.nodejs_24 "Node.js (24 or newer) for the bots and for npm, which installs the Claude engine";

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
    environment.systemPackages = [cfg.package];

    # The first install of the Claude engine, as the guide installs it. Claude
    # Code updates itself in the same prefix.
    systemd.services.openmausbot-install = {
      description = "Install OpenMausBot's Claude engine";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      before = ["openmausbot.service"];
      requiredBy = ["openmausbot.service"];
      unitConfig.ConditionPathExists = "!${prefix}/bin/claude";
      # npm runs install scripts with sh.
      path = [cfg.nodejs pkgs.git pkgs.bash];
      environment.HOME = home;
      serviceConfig = {
        Type = "oneshot";
        User = user;
        WorkingDirectory = home;
        ExecStart = install "@anthropic-ai/claude-code";
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
          # The bots' browser. The Chrome for Testing that the browser install
          # downloads is linked for FHS distros and does not start here.
          OMB_CHROME_PATH = getExe pkgs.chromium;
        }
        // cfg.environment
        // {HOME = home;};
      # The tunnel's address is reserved by `openmausbot login`, which needs an
      # emailed code: start the service after it.
      unitConfig.ConditionPathExists = mkIf (elem "--tunnel" cfg.args) "${home}/.openmausbot/tunnel-account.json";
      serviceConfig = {
        User = user;
        WorkingDirectory = home;
        ExecStart = escapeShellArgs ([(getExe cfg.package) "serve"] ++ cfg.args);
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
