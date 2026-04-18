{
  lib,
  config,
  pkgs,
  inputs,
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
    home.packages = [
      inputs.nix-claude-code.packages.${pkgs.system}.default
      pkgs.nodejs
      pkgs.python3
      pkgs.uv
    ];

    home.file.".claude" = {
      source = "${inputs.cc-dotfiles}/.claude";
      recursive = true;
    };

    capybara.impermanence.directories = [
      ".claude"
      ".local/share/uv"
      ".cache/uv"
      ".npm"
    ];
    capybara.impermanence.files = [".claude.json"];
  };
}
