{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  print-battery-status = pkgs.writeShellScript "print-battery-status" ''
    BAT_INFO=$(${pkgs.acpi}/bin/acpi -b | head -n1)

    STATUS=$(echo "$BAT_INFO" | grep -o "Charging\|Discharging\|Full")
    PERC=$(echo "$BAT_INFO" | grep -o "[0-9]\+%" | tr -d '%')

    if [ -z "$PERC" ]; then echo ""; exit 0; fi

    INDEX=$((PERC / 10))
    if [ "$INDEX" -ge 10 ]; then INDEX=9; fi

    if [ "$STATUS" = "Charging" ]; then
        ICONS=("󰢟" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅")
    else
        ICONS=("󱃍" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰁹")
    fi

    echo "''${ICONS[$INDEX]} $PERC%"
  '';
in {
  config = {
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          grace = 1;
          hide_cursor = true;
          ignore_empty_input = true;
          immediate_render = false;
          text_trim = true;
          fractional_scaling = 2;
          fail_timeout = 50;
        };

        background = [
          {
            monitor = "";
            path = "screenshot";
            blur_passes = 2;
            blur_size = 2;
            contrast = 0.8916;
            brightness = 0.7172;
            vibrancy = 0.1696;
            vibrancy_darkness = 0.0;
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "250, 60";
            outline_thickness = 0;
            outer_color = "rgba(0, 0, 0, 0)";
            dots_size = 0.1;
            dots_spacing = 1;
            dots_center = true;
            inner_color = "rgba(0, 0, 0, 0)";
            font_color = "rgba(255, 255, 255, 1)";
            fade_on_empty = false;
            font_family = "JetBrains Mono Nerd Font Mono";
            placeholder_text = "<b> $USER</b>";
            hide_input = false;
            position = "0, 20";
            halign = "center";
            valign = "bottom";
            zindex = 10;
            fail_color = "rgb(ef343a)";
            capslock_color = "rgb(ee6e54)";
            check_color = "rgb(be95ff)";
          }
        ];

        label = [
          # HOUR
          {
            monitor = "";
            text = ''cmd[update:1000] echo -e "$(date +"%H")"'';
            color = "rgba(255, 255, 255, 1)";
            shadow_passes = 2;
            shadow_size = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 1.2;
            font_size = 150;
            font_family = "JetBrains Mono Nerd Font Mono Bold";
            position = "0, 150";
            halign = "center";
            valign = "center";
          }
          # MINUTES
          {
            monitor = "";
            text = ''cmd[update:1000] echo -e "$(date +"%M")"'';
            color = "rgba(255, 255, 255, 1)";
            shadow_passes = 2;
            shadow_size = 3;
            shadow_color = "rgb(0,0,0)";
            shadow_boost = 1.2;
            font_size = 150;
            font_family = "JetBrains Mono Nerd Font Mono Bold";
            position = "0, -30";
            halign = "center";
            valign = "center";
          }
          # DATE
          {
            monitor = "";
            text = ''cmd[update:1000] echo -e "$(date +"%a, %d %b, %Y")"'';
            color = "rgba(255, 255, 255, 1)";
            font_size = 17;
            font_family = "JetBrains Mono Nerd Font Mono";
            position = "0, -150";
            halign = "center";
            valign = "center";
          }
          # Battery Information
          {
            monitor = "";
            text = ''cmd[update:1000] echo -e "$(${print-battery-status})"'';
            color = "rgba(255, 255, 255, 1)";
            font_size = 12;
            font_family = "JetBrains Mono Nerd Font ExtraBold";
            position = "-20, 20";
            halign = "right";
            valign = "bottom";
          }
        ];
      };
    };
  };
}
