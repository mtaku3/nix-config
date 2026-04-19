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

    capybara.impermanence.directories = [
      ".claude"
      ".local/share/uv"
      ".cache/uv"
      ".npm"
    ];
    capybara.impermanence.files = [
      ".claude.json"
      ".local/bin/claude"
    ];
  };
}
