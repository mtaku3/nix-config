{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  top = config.capybara.wayland.windowManager.hyprland;
in {
  config = mkIf top.enable {
    services.hyprpaper = {
      enable = true;

      settings = {
        "$path" = "${pkgs.capybara.wallpapers}/wallhaven-3zmr6y.png";
        preload = "$path";
        wallpaper = ", $path";
      };
    };
  };
}
