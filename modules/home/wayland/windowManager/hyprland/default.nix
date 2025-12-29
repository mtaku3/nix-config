{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.wayland.windowManager.hyprland;
in {
  options.capybara.wayland.windowManager.hyprland = {
    enable = mkBoolOpt false "Whether to enable the Hyprland";
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
    };
  };
}
