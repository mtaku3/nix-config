{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  hyprland-enabled = users-any (cfg: cfg.capybara.wayland.windowManager.hyprland.enable) config;
in {
  imports = [
    ./hyprlock.nix
  ];

  config = mkIf hyprland-enabled {
    capybara.greetd.wayland-sessions = [
      {
        name = "Hyprland";
        script = "$HOME/.nix-profile/bin/hyprland";
      }
    ];
  };
}
