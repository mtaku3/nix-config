{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.arandr;
in {
  options.capybara.app.desktop.arandr = {
    enable = mkBoolOpt false "Whether to enable the arandr";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.arandr];
  };
}
