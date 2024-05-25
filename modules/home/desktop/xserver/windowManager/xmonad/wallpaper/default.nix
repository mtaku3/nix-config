{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = mkIf config.capybara.desktop.xserver.windowManager.xmonad.enable {
    programs.feh = enabled;
  };
}
