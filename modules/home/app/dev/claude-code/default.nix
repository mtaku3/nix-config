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
    home.packages = [pkgs.unstable.claude-code pkgs.unstable.repomix pkgs.capybara.superclaude];

    capybara.impermanence.directories = [".claude"];
    capybara.impermanence.files = [".claude.json"];
  };
}
