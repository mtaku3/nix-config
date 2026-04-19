{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.claude-code;
in {
  options.capybara.app.dev.claude-code = {
    enable = mkBoolOpt false "Whether to enable the claude-code";
  };

  config = mkIf cfg.enable {
    # claude-code is installed via the native installer
    # (curl -fsSL https://claude.ai/install.sh | bash) so it can self-update.
    # The installer drops a launcher at ~/.local/bin/claude and runtime
    # files under ~/.claude/local/.
    home.packages = [
      pkgs.nodejs
      pkgs.python3
      pkgs.uv
    ];

    home.sessionPath = ["$HOME/.local/bin"];

    home.activation.installClaudeCode = let
      installer = pkgs.writeShellApplication {
        name = "install-claude-code";
        runtimeInputs = [pkgs.curl];
        text = ''
          if [ ! -x "$HOME/.local/bin/claude" ]; then
            curl -fsSL https://claude.ai/install.sh | bash
          fi
        '';
      };
    in {
      after = ["writeBoundary"];
      before = [];
      data = "run ${installer}/bin/install-claude-code";
    };

    capybara.impermanence.directories = [
      ".claude"
      ".local/bin"
      ".local/share/uv"
      ".cache/uv"
      ".npm"
    ];
    capybara.impermanence.files = [
      ".claude.json"
    ];
  };
}
