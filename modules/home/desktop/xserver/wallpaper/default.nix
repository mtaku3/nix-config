{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.xserver.wallpaper;
in {
  options.capybara.desktop.xserver.wallpaper = {
    enable = mkBoolOpt false "Whether to enable the wallpaper";
  };

  config = mkIf cfg.enable {
    capybara.desktop.xserver.preStart = "feh --bg-scale ${pkgs.capybara.wallpapers}/wallhaven-3zmr6y.jpg";
    programs.feh = enabled;
  };
}
