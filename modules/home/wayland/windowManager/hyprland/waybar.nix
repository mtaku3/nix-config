{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = {
    programs.waybar = {
      enable = true;

      settings = {
        mainBar = {
          layer = "top";
          output = ["*"];
          position = "top";
          mod = "dock";
          height = 28;
          exclusive = true;
          passthrough = false;
          "gtk-layer-shell" = true;
          reload_style_on_change = true;

          "modules-left" = [
            "custom/space"
            "custom/start"
            "clock"
            "custom/end"
            "custom/start"
            "disk"
            "cpu"
            "memory"
            "temperature"
            "custom/end"
            "custom/space"
          ];

          "modules-center" = [
            "custom/space"
            "custom/start"
            "hyprland/workspaces"
            "hyprland/window"
            "custom/end"
            "custom/space"
          ];

          "modules-right" = [
            "custom/space"
            "custom/start"
            "backlight"
            "pulseaudio"
            "pulseaudio#microphone"
            "battery"
            "custom/end"
            "custom/start"
            "tray"
            "custom/end"
            "custom/space"
          ];

          cpu = {
            interval = 10;
            format = "󰍛 {usage}%";
            "format-alt" = "{icon0}{icon1}{icon2}{icon3}";
            "format-icons" = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
          };

          memory = {
            states = {
              c = 90;
              h = 60;
              m = 30;
            };
            interval = 10;
            format = "󰾆 {percentage}%";
            "format-m" = "󰾅 {percentage}%";
            "format-h" = "󰓅 {percentage}%";
            "format-c" = " {percentage}%";
            "format-alt" = "󰾆 {percentage}%";
            "max-length" = 10;
            tooltip = true;
            "tooltip-format" = "  {used:0.1f}GB/{total:0.1f}GB";
          };

          temperature = {
            "critical-threshold" = 80;
            "warning-threshold" = 60;
            "format-critical" = " {temperatureC}°C";
            "tooltip-format" = "{temperatureF}°F\n{temperatureK} K";
            format = "{icon} {temperatureC}°C";
            "format-icons" = ["" "" "" "" ""];
          };

          clock = {
            format = "󰥔  {:%H:%M}";
            "tooltip-format" = "<span>{calendar}</span>";
            calendar = {
              mode = "month";
              "mode-mon-col" = 3;
              "on-scroll" = 1;
              "on-click-right" = "mode";
              format = {
                months = "<span color='#ffead3'><b>{}</b></span>";
                weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                today = "<span color='#ff6699'><b>{}</b></span>";
              };
            };
            actions = {
              "on-click-right" = "mode";
              "on-click-forward" = "tz_up";
              "on-click-backward" = "tz_down";
              "on-scroll-up" = "shift_up";
              "on-scroll-down" = "shift_down";
            };
          };

          "hyprland/workspaces" = {
            "all-outputs" = true;
            "active-only" = false;
            "on-click" = "activate";
            signal = 2;
          };

          "hyprland/window" = {
            format = "  {title}";
            "separate-outputs" = true;
            rewrite = {
              "  [~/](.*)" = " $1";
              "  nvim(.*)" = " $1";
              "  yazi(.*)" = "󰉋 $1";
            };
            "max-length" = 50;
          };

          "hyprland/submap" = {
            format = "<span text_transform='uppercase'>{}</span>";
            "on-click" = "hyprctl dispatch submap reset";
            tooltip = false;
          };

          pulseaudio = {
            format = "{icon}  {volume}%";
            "format-muted" = "󰖁  {volume}%";
            "on-click" = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
            "on-scroll-up" = "pactl set-sink-volume @DEFAULT_SINK@ +1%";
            "on-scroll-down" = "pactl set-sink-volume @DEFAULT_SINK@ -1%";
            "tooltip-format" = "{desc}";
            "format-icons" = {
              default = ["" "" "" "" ""];
            };
          };

          "pulseaudio#microphone" = {
            format = "{format_source}";
            "format-source" = " {volume}%";
            "format-source-muted" = " {volume}%";
            "on-click" = "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
            "on-scroll-up" = "pactl set-source-volume @DEFAULT_SOURCE@ +1%";
            "on-scroll-down" = "pactl set-source-volume @DEFAULT_SOURCE@ -1%";
            "tooltip-format" = "{source_desc}";
            "scroll-step" = 5;
          };

          tray = {
            "icon-size" = 14;
            spacing = 5;
          };

          battery = {
            interval = 30;
            states = {
              good = 70;
              warning = 30;
              critical = 10;
            };
            format = "{icon} {capacity}%";
            "format-charging" = " {capacity}%";
            "format-plugged" = " {capacity}%";
            "format-icons" = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          };

          "custom/power" = {
            format = "";
            "on-click" = "pkill wlogout || wlogout";
            "tooltip-format" = "Power menu";
          };

          # --- Spacers ---
          "custom/start" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/space" = {
            format = "  ";
            interval = "once";
            tooltip = false;
          };

          disk = {
            interval = 30;
            format = "  {percentage_free}%";
            "tooltip-format" = "{free} out of {total} available";
            path = "/";
          };

          backlight = {
            device = "acpi_video1";
            format = "{icon} {percent}%";
            "tooltip-format" = "Monitor brightness";
            "format-icons" = ["󰃞" "󰃝" "󰃠"];
          };
        };
      };

      style = ''
        @define-color bar-bg rgba(0, 0, 0, 0);
        @define-color main-bg #161616;
        @define-color main-fg #f2f4f8;
        @define-color wb-act-bg #b6b8bb;
        @define-color wb-act-fg #161616;
        @define-color wb-hvr-bg #be95ff;
        @define-color wb-hvr-fg #161616;
        @define-color submap #be95ff;

        * {
          border: none;
          border-radius: 0px;
          font-family: "JetBrains Mono Nerd Font";
          font-weight: bold;
          font-size: 14px;
          min-height: 10px;
        }

        window#waybar {
          background: @bar-bg;
        }

        tooltip {
          background: @main-bg;
          color: @main-fg;
          border-radius: 7px;
          border-width: 0px;
        }

        #workspaces button {
          box-shadow: none;
          text-shadow: none;
          padding: 0px;
          border-radius: 8px;
          margin-top: 2px;
          margin-bottom: 2px;
          margin-left: 0px;
          padding-left: 2px;
          padding-right: 2px;
          margin-right: 0px;
          color: @main-fg;
          animation: ws_normal 20s ease-in-out 1;
        }

        #workspaces button.active {
          background: @wb-act-bg;
          color: @wb-act-fg;
          margin-left: 2px;
          padding-left: 11px;
          padding-right: 11px;
          margin-right: 2px;
          animation: ws_active 20s ease-in-out 1;
          transition: all 0.4s cubic-bezier(0.55, -0.68, 0.48, 1.682);
        }

        #workspaces button:hover {
          background: @wb-hvr-bg;
          color: @wb-hvr-fg;
          animation: ws_hover 20s ease-in-out 1;
          transition: all 0.3s cubic-bezier(0.55, -0.68, 0.48, 1.682);
        }

        #tray menu * {
          min-height: 16px;
        }

        #tray menu separator {
          min-height: 10px;
        }

        #backlight,
        #battery,
        #clock,
        #cpu,
        #memory,
        #disk,
        #pulseaudio,
        #temperature,
        #tray,
        #window,
        #workspaces,
        #submap,
        #custom-power,
        #custom-start,
        #custom-end {
          color: @main-fg;
          background: @main-bg;
          opacity: 1;
          margin: 3px 0px 3px 0px;
          padding-left: 4px;
          padding-right: 4px;
        }

        #submap {
          border-radius: 19px;
          padding-right: 12px;
          padding-left: 12px;
          background: @submap;
          color: @main-bg;
        }

        #workspaces,
        #taskbar {
          padding: 0px;
        }

        #custom-end {
          border-radius: 0px 19px 19px 0px;
          margin-right: 8px;
          padding-right: 0px;
        }

        #custom-start {
          border-radius: 19px 0px 0px 19px;
          margin-left: 8px;
          padding-left: 0px;
        }

        #custom-space {
          background: @bar-bg;
        }
      '';
    };
  };
}
