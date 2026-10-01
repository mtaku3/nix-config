{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.amp;
  home = config.home.homeDirectory;

  # Amp is installed by its own installer into ~/.amp so that it can keep
  # itself up to date, instead of being pinned in the Nix store. The wrapper
  # installs it on first use and otherwise just execs it.
  ampWrapper = pkgs.writeShellApplication {
    name = "amp";
    text = ''
      AMP_HOME=$HOME/.amp

      if [[ ! -x $AMP_HOME/bin/amp ]]; then
        echo "amp: installing into $AMP_HOME" >&2
        # With ~/.local/bin on PATH the installer only symlinks amp there and
        # leaves the (home-manager managed) shell profile alone.
        ${getExe pkgs.curl} -fsSL https://ampcode.com/install.sh \
          | AMP_HOME=$AMP_HOME \
            PATH="$HOME/.local/bin:${makeBinPath (with pkgs; [coreutils curl gnugrep gzip])}:$PATH" \
            ${getExe pkgs.bash}
      fi

      exec "$AMP_HOME/bin/amp" "$@"
    '';
  };

  runtimePath = concatStringsSep ":" [
    "${home}/.local/bin"
    "${config.home.profileDirectory}/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];
in {
  options.capybara.app.dev.amp = with types; {
    enable = mkBoolOpt false "Whether to enable Amp";

    runner = {
      enable = mkBoolOpt false "Whether to run an Amp runner (amp --no-tui) as a user service";

      id = mkOpt str "" "Stable runner ID shown on ampcode.com";

      workDir = mkOpt str "Workspaces" "Directory the runner starts in, relative to home; new directories created from ampcode.com land here";

      extraArgs = mkOpt (listOf str) ["--discover-dirs"] "Extra arguments passed to amp --no-tui; by default it serves every git checkout up to two levels under workDir";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.runner.enable -> cfg.runner.id != "";
        message = "capybara.app.dev.amp.runner.id must be set when the runner is enabled";
      }
    ];

    home.packages = [ampWrapper];

    systemd.user.services.amp-runner = mkIf cfg.runner.enable {
      Unit.Description = "Amp runner";
      Service = {
        WorkingDirectory = "${home}/${cfg.runner.workDir}";
        ExecStart = escapeShellArgs ([(getExe ampWrapper) "--no-tui" "--runner-id" cfg.runner.id] ++ cfg.runner.extraArgs);
        Environment = ["PATH=${runtimePath}"];
        # The runner restarts itself after self-updating, so always bring it back.
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
        ".amp"
        ".config/amp"
        ".local/share/amp"
      ];
  };
}
