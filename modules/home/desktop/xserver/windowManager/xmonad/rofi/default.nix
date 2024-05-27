{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = mkIf config.capybara.desktop.xserver.windowManager.xmonad.enable {
    programs.rofi = {
      enable = true;
      font = "JetBrainsMono NF 10";
      location = "top";
      theme = ./theme.rasi;
    };
  };
}
