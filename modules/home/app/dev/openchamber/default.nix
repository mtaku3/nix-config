{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.openchamber;
  home = config.home.homeDirectory;
  envPath = config.age.secrets."openchamber/env".path;
  npmPrefix = "${home}/.openchamber/npm-global";

  # OpenChamber and OpenCode are installed with npm into their own global
  # prefix rather than pinned in the Nix store, so that OpenChamber's updater
  # and `opencode upgrade` (both of which reinstall through npm) keep them up
  # to date. OpenChamber runs its update as a systemd-run job that inherits
  # only PATH, so the prefix is baked into an npm shim on PATH instead of
  # being passed through the environment.
  npmShim = pkgs.writeShellScriptBin "npm" ''
    export NPM_CONFIG_PREFIX=${npmPrefix}
    exec ${pkgs.nodejs}/bin/npm "$@"
  '';

  # The wrappers install on first use and otherwise just exec.
  mkNpmWrapper = name: package:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [npmShim pkgs.nodejs];
      text = ''
        if [[ ! -x ${npmPrefix}/bin/${name} ]]; then
          echo "${name}: installing ${package} into ${npmPrefix}" >&2
          npm install --global --no-audit --no-fund ${package}
        fi

        exec ${npmPrefix}/bin/${name} "$@"
      '';
    };

  openchamberWrapper = mkNpmWrapper "openchamber" "@openchamber/web";
  # OpenChamber needs OpenCode 2.x, which is only published as @opencode/cli;
  # the opencode.ai installer and opencode-ai still ship the 1.x line.
  opencodeWrapper = mkNpmWrapper "opencode" "@opencode/cli";

  runtimePath = concatStringsSep ":" [
    "${npmPrefix}/bin"
    (makeBinPath [npmShim pkgs.nodejs])
    "${config.home.profileDirectory}/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];
in {
  options.capybara.app.dev.openchamber = with types; {
    enable = mkBoolOpt false "Whether to enable OpenChamber";

    server = {
      enable = mkBoolOpt false "Whether to run the OpenChamber web server (openchamber serve) as a user service";

      port = mkOpt port 3000 "Loopback port the web server listens on";

      workDir = mkOpt str "Workspaces" "Directory the web server starts in, relative to home";

      relayUrl = mkOpt (nullOr str) null "Self-hosted relay endpoint (wss://.../ws) pinned for relay pairing; null uses the OpenChamber-hosted relay";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      openchamberWrapper
      opencodeWrapper
    ];

    # The env file must set OPENCHAMBER_UI_PASSWORD: without it the server
    # authenticates nothing, including requests tunneled through the relay.
    systemd.user.services.openchamber = mkIf cfg.server.enable {
      Unit = {
        Description = "OpenChamber web server";
        After = ["agenix.service"];
        Wants = ["agenix.service"];
      };
      Service = {
        WorkingDirectory = "${home}/${cfg.server.workDir}";
        ExecStart = escapeShellArgs [(getExe openchamberWrapper) "serve" "--foreground" "--port" (toString cfg.server.port)];
        EnvironmentFile = envPath;
        Environment =
          [
            "PATH=${runtimePath}"
            "OPENCHAMBER_HOST=127.0.0.1"
          ]
          ++ optional (cfg.server.relayUrl != null) "OPENCHAMBER_RELAY_URL=${cfg.server.relayUrl}";
        # Updates from the UI install through a systemd-run job that then
        # restarts this unit by name (openchamber.service).
        Restart = "always";
        RestartSec = 10;
      };
      Install.WantedBy = ["default.target"];
    };

    capybara.impermanence.directories =
      map (directory: {
        inherit directory;
        method = "symlink";
      }) [
        ".openchamber"
        ".config/openchamber"
        ".config/opencode"
        ".local/share/opencode"
        ".local/state/opencode"
      ];
  };
}
