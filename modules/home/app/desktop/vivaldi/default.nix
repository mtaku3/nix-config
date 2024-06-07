{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.vivaldi;
in {
  options.capybara.app.desktop.vivaldi = {
    enable = mkBoolOpt false "Whether to enable the vivaldi";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.unstable.vivaldi];
    capybara.impermanence.directories = [".config/vivaldi"];
  };
}
