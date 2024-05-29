{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.flameshot;
in {
  config = mkIf config.capybara.xserver.windowManager.xmonad.enable {
    home.packages = [pkgs.flameshot];
    xdg.configFile."flameshot/flameshot.ini".source = ./flameshot.ini;
  };
}
