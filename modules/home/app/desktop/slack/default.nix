{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.slack;
in {
  options.capybara.app.desktop.slack = {
    enable = mkBoolOpt false "Whether to enable the slack";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.slack];
    capybara.impermanence.directories = [".config/Slack"];
  };
}
