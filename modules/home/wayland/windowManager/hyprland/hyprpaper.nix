{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = {
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
