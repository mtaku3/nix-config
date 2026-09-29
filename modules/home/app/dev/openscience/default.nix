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

  configFile = pkgs.writeText "openscience.json" (builtins.toJSON {
    "$schema" = "https://openscience.sh/config.json";
    autoupdate = false;
    model = cfg.model;
    small_model = cfg.smallModel;
    provider = genAttrs ["anthropic" "openai"] (_: {
      options = {
        baseURL = cfg.cliproxyBaseUrl;
        apiKey = "{env:CLIPROXY_API_KEY}";
      };
    });
  });

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

    cliproxyBaseUrl = mkOpt str "https://cliproxy.mtaku3.com/v1" "CLIProxyAPI endpoint used as the anthropic and openai providers";

    model = mkOpt str "anthropic/claude-opus-5-5" "Default model, as provider/model";

    smallModel = mkOpt str "anthropic/claude-haiku-4-5-20251001" "Model for titles and other small tasks, as provider/model";

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

    systemd.user.services.openscience = {
      Unit = {
        Description = "OpenScience runtime";
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

    systemd.user.tmpfiles.rules = ["d ${workDir} 0755 - - -"];

    capybara.impermanence.directories = [
      ".openscience"
      ".config/openscience"
      ".local/share/openscience"
      ".local/state/openscience"
    ];
  };
}
