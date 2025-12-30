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
  imports = [
    ./waybar.nix
    ./wlogout.nix
    ./fuzzel.nix
    ./hyprlock.nix
    ./hyprpaper.nix
  ];

  options.capybara.wayland.windowManager.hyprland = {
    enable = mkBoolOpt false "Whether to enable the Hyprland";
  };

  config = mkIf cfg.enable {
    capybara.app.desktop.flameshot.enable = mkDefault true;

    wayland.windowManager.hyprland = {
      enable = true;

      settings = let
        variables = {
          "$mod" = "SUPER";

          "$background" = "rgb(161616)";
          "$foreground" = "rgb(f2f4f8)";

          "$color0" = "rgb(161616)";
          "$color1" = "rgb(252525)";
          "$color2" = "rgb(353535)";
          "$color3" = "rgb(484848)";
          "$color4" = "rgb(7b7c7e)";
          "$color5" = "rgb(f2f4f8)";
          "$color6" = "rgb(b6b8bb)";
          "$color7" = "rgb(e4e4e5)";
          "$color8" = "rgb(ee5396)";
          "$color9" = "rgb(3ddbd9)";
          "$color10" = "rgb(08bdba)";
          "$color11" = "rgb(25be6a)";
          "$color12" = "rgb(33b1ff)";
          "$color13" = "rgb(78a9ff)";
          "$color14" = "rgb(be95ff)";
          "$color15" = "rgb(ff7eb6)";

          "$unlockedgroupbar" = "be95ff";
          "$lockedgroupbar" = "a269ff";

          "$app2unit" = "${pkgs.unstable.app2unit}/bin/app2unit --";
        };
        autostart = {
          exec-once = [
            "$app2unit waybar"
          ];
        };
      in
        mkMerge [
          variables
          autostart
          {
            general = {
              layout = "master";

              gaps_in = 6;
              gaps_out = "10, 18, 18, 18";

              border_size = 0;

              "col.active_border" = "$color9";
              "col.inactive_border" = "$color4";

              resize_on_border = true;
              hover_icon_on_border = true;

              allow_tearing = false;
            };

            decoration = {
              rounding = 10;
              rounding_power = 2;

              active_opacity = 0.85;
              inactive_opacity = 0.7;
              fullscreen_opacity = 1.0;

              border_part_of_window = false;

              dim_inactive = false;
              dim_strength = 0.1;
              dim_special = 0.5;

              shadow = {
                enabled = false;
                range = 3;
                render_power = 1;
                color = "$color12";
                color_inactive = "$color4";
              };

              blur = {
                enabled = true;
                size = 8;
                passes = 2;
                ignore_opacity = true;
                new_optimizations = true;
                special = true;
                popups = false;
                noise = 0;
                brightness = 0.9;
              };
            };

            animations = {
              enabled = true;

              workspace_wraparound = true;

              bezier = [
                "easeOutQuint,0.23,1,0.32,1"
                "easeInOutCubic,0.65,0.05,0.36,1"
                "linear,0,0,1,1"
                "almostLinear,0.5,0.5,0.75,1.0"
                "quick,0.15,0,0.1,1"
              ];

              animation = [
                "global, 1, 10, default"
                "border, 1, 5.39, easeOutQuint"
                "windows, 1, 4.79, easeOutQuint"
                "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
                "windowsOut, 1, 1.49, linear, popin 87%"
                "fadeIn, 1, 1.73, almostLinear"
                "fadeOut, 1, 1.46, almostLinear"
                "fade, 1, 3.03, quick"
                "layers, 1, 3.81, easeOutQuint"
                "layersIn, 1, 4, easeOutQuint, fade"
                "layersOut, 1, 1.5, linear, fade"
                "fadeLayersIn, 1, 1.79, almostLinear"
                "fadeLayersOut, 1, 1.39, almostLinear"
                "workspaces, 1, 1.94, almostLinear, fade"
                "workspacesIn, 1, 1.21, almostLinear, fade"
                "workspacesOut, 1, 1.94, almostLinear, fade"
              ];
            };

            bind =
              [
                "$mod, RETURN, exec, $app2unit kitty"
                "$mod, B, exec, $app2unit vivaldi"
                "$mod, D, exec, fuzzel"
                "$mod SHIFT, S, exec, $app2unit flameshot gui"

                "$mod, Escape, exec, pidof hyprlock || hyprlock"
                "$mod SHIFT, Escape, exec, systemctl suspend"

                "$mod SHIFT, E, exit,"
                "$mod SHIFT, Q, killactive,"
                "$mod, F, fullscreen, 1"
                "$mod, SPACE, togglefloating,"
                "$mod, H, layoutmsg, cycleprev noloop"
                "$mod, L, layoutmsg, cyclenext noloop"
                "$mod SHIFT, H, layoutmsg, swapprev noloop"
                "$mod SHIFT, L, layoutmsg, swapnext noloop"
              ]
              ++ (
                builtins.concatLists (builtins.genList (
                    x: let
                      ws = toString (x + 1);
                    in [
                      "$mod, ${ws}, workspace, ${ws}"
                      "$mod SHIFT, ${ws}, movetoworkspace, ${ws}"
                    ]
                  )
                  9)
              )
              ++ [
                "$mod, 0, workspace, 10"
                "$mod SHIFT, 0, movetoworkspace, 10"
              ];

            bindm = [
              "$mod, mouse:272, movewindow"
              "$mod SHIFT, mouse:272, resizewindow"
            ];

            bindel = [
              ", XF86AudioRaiseVolume, exec, pactl set-sink-volume 0 +2%"
              ", XF86AudioLowerVolume, exec, pactl set-sink-volume 0 -2%"
              ", XF86AudioMute, exec, pactl set-sink-mute 0 toggle"
            ];

            monitor = [
              ", preferred, auto, 1"
            ];

            input = {
              kb_layout = "jp";
              follow_mouse = 1;
              touchpad = {
                natural_scroll = true;
              };
            };
          }
        ];
    };
  };
}
