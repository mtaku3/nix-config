{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.claude-code;

  claudeWrapper = pkgs.writeShellApplication {
    name = "claude";
    # No runtimeInputs: the wrapper deliberately calls the user's
    # installer-managed binary at ~/.local/bin/claude by absolute path,
    # and only uses bash builtins + `cat` (provided by writeShellApplication's
    # default PATH) for the missing-install message.
    text = ''
      REAL=$HOME/.local/bin/claude

      if [[ ! -x $REAL ]]; then
        cat >&2 <<'EOF'
      claude-code is not installed.

      Install with:
        curl -fsSL https://claude.ai/install.sh | bash

      Docs: https://docs.claude.com/en/docs/claude-code/setup
      EOF
        exit 127
      fi

      ${cfg.preStart}

      exec "$REAL" "$@"
    '';
    meta = {
      description = "Wrapper around the installer-managed claude-code binary";
      mainProgram = "claude";
    };
  };
in {
  options.capybara.app.dev.claude-code = {
    enable = mkBoolOpt false "Whether to enable the claude-code";

    preStart = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Shell snippet sourced by the claude wrapper before exec'ing the
        installer-managed binary. Intended for exporting secrets read from
        agenix-managed files, e.g.

          export ANTHROPIC_API_KEY=$(cat ''${config.age.secrets.anthropic.path})

        Runs under `set -euo pipefail`; a non-zero exit aborts the wrapper
        before claude-code runs.
      '';
    };
  };

  config = mkIf cfg.enable {
    # claude-code is installed via the native installer
    # (curl -fsSL https://claude.ai/install.sh | bash) so it can self-update.
    # The installer drops versioned binaries under ~/.local/share/claude/versions/
    # and a launcher symlink at ~/.local/bin/claude pointing at the active
    # version. The wrapper below shadows that launcher on PATH so we can run
    # preStart hooks (typically secret exports) first.
    home.packages = [
      claudeWrapper
      pkgs.nodejs
      pkgs.python3
      pkgs.uv
      pkgs.socat
    ] ++ lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.bubblewrap;

    home.sessionPath = ["$HOME/.npm-global/bin"];

    home.file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.npm-global
    '';

    capybara.impermanence.directories = [
      ".claude"
      ".mem0"
      ".config/caveman"
      ".local/bin"
      ".local/share/claude"
      ".local/share/uv"
      ".cache/uv"
      ".npm"
      ".npm-global"
    ];
    capybara.impermanence.files = [
      ".claude.json"
    ];
  };
}
