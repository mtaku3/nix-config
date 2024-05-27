{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = mkIf config.capybara.xserver.windowManager.xmonad.enable {
    home.packages = [pkgs.trayer];
  };
}
