{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.openscience;
  envPath = config.age.secrets."openscience/env".path;
  workDir = "${config.home.homeDirectory}/${cfg.workDir}";

  # Layered over ~/.config/openscience/openscience.json via OPENSCIENCE_CONFIG,
  # which outranks the global file but not project configs. The global file
  # stays writable because the workspace's Customize pages save into it.
  configFile = pkgs.writeText "openscience.json" (builtins.toJSON {
    "$schema" = "https://openscience.sh/config.json";
    autoupdate = false;
    model = cfg.model;
    # Keep the models.dev catalog for the built-in anthropic provider (limits,
    # thinking, tool use) and only move its endpoint to CLIProxyAPI, so the
    # requests draw on the Claude subscription behind the proxy.
    provider.anthropic.options = {
      baseURL = cfg.cliproxyBaseUrl;
      apiKey = "{env:CLIPROXY_API_KEY}";
    };
  });

  # A systemd --user unit inherits almost no PATH, and the agent shells out to
  # whatever it finds there. Put the user's profile first-class so the runtime
  # sees the same tools as an interactive shell, plus the science toolchain.
  runtimePath = concatStringsSep ":" [
    (makeBinPath cfg.runtimePackages)
    "${config.home.profileDirectory}/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];
in {
  options.capybara.app.dev.openscience = with types; {
    enable = mkBoolOpt false "Whether to enable OpenScience";

    package = mkOpt package pkgs.capybara.openscience "OpenScience package";

    baseUrl = mkOpt str "https://openscience.mtaku3.com" "Public origin the workspace is served from";

    port = mkOpt port 4096 "Loopback port the runtime listens on";

    workDir = mkOpt str "Workspaces/openscience" "Project folder the runtime opens, relative to home";

    cliproxyBaseUrl = mkOpt str "https://cliproxy.mtaku3.com/v1" "CLIProxyAPI endpoint used as the anthropic provider";

    model = mkOpt str "anthropic/claude-opus-5-5" "Default model, as provider/model";

    runtimePackages = mkOpt (listOf package) (with pkgs; [
      bashInteractive
      coreutils
      git
      ripgrep
      curl
      python3
      uv
    ]) "Packages placed on the runtime's PATH ahead of the user profile";
  };

  config = mkIf cfg.enable {
    # The CLI reads the same layered config, and needs the proxy key to reach
    # the model. The bearer token is left out on purpose: a CLI-started server
    # would demand it from its own local workspace tab.
    home.packages = [
      (pkgs.writeShellApplication {
        name = "openscience";
        text = ''
          if [[ -r ${envPath} ]]; then
            CLIPROXY_API_KEY=$(sed -n 's/^CLIPROXY_API_KEY=//p' ${envPath})
            export CLIPROXY_API_KEY
          fi
          export OPENSCIENCE_CONFIG=${configFile}
          export OPENSCIENCE_DISABLE_AUTOUPDATE=1
          exec ${getExe cfg.package} "$@"
        '';
      })
    ];

    # The runtime binds 127.0.0.1 only; nginx on helios republishes it to
    # Traefik, rewriting Host and adding OPENSCIENCE_AUTH_TOKEN as a bearer.
    # --cors admits the public origin the browser sends on API calls.
    systemd.user.services.openscience = {
      Unit = {
        Description = "OpenScience runtime";
        # EnvironmentFile is read at start; agenix.service is a oneshot with no
        # Before=, so without this the unit can race it and start keyless.
        After = ["agenix.service"];
        Wants = ["agenix.service"];
      };
      Service = {
        WorkingDirectory = workDir;
        ExecStart = "${getExe cfg.package} serve --port ${toString cfg.port} --cors ${cfg.baseUrl}";
        EnvironmentFile = envPath;
        Environment = [
          "PATH=${runtimePath}"
          "OPENSCIENCE_CONFIG=${configFile}"
          "OPENSCIENCE_DISABLE_AUTOUPDATE=1"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = ["default.target"];
    };

    # WorkingDirectory is entered before any ExecStartPre could create it.
    systemd.user.tmpfiles.rules = ["d ${workDir} 0755 - - -"];

    # ~/.openscience is the data root: sessions, account sign-in, provider
    # keys, logs. The XDG dirs hold the writable global config, caches of the
    # skill library, and runtime state.
    capybara.impermanence.directories = [
      ".openscience"
      ".config/openscience"
      ".local/share/openscience"
      ".local/state/openscience"
    ];
  };
}
