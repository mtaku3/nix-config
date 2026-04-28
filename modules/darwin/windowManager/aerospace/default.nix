{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.windowManager.aerospace;
in {
  options.capybara.windowManager.aerospace = {
    enable = mkBoolOpt false "Whether to enable the aerospace";
  };

  imports = [./autoraise.nix];

  config = mkIf cfg.enable {
    services.aerospace = let
      aerospace = pkgs.aerospace;
    in {
      enable = true;
      package = aerospace;
      settings = {
        default-root-container-layout = "tiles";
        default-root-container-orientation = "horizontal";
        on-focus-changed = ["move-mouse window-lazy-center"];
        exec-on-workspace-change = ["/usr/bin/env" "bash" "-c" "${aerospace}/bin/aerospace move-mouse window-lazy-center"];
        workspace-to-monitor-force-assignment = {
          "1" = "main";
          "2" = "main";
          "3" = "main";
          "4" = "main";
          "5" = "main";
          "6" = "main";
          "7" = "main";
          "8" = "main";
          "9" = "main";
          "10" = "main";
          "11" = 1;
          "12" = 3;
        };
        mode.main.binding = {
          alt-enter = "exec-and-forget open -n -a kitty";
          alt-b = "exec-and-forget open -n -a vivaldi";
          alt-shift-q = "close --quit-if-last-window";
          alt-j = "focus --ignore-floating left";
          alt-k = "focus --ignore-floating right";
          alt-h = "focus-monitor prev";
          alt-l = "focus-monitor next";
          alt-shift-j = "move left";
          alt-shift-k = "move right";
          alt-shift-h = "move-node-to-monitor --focus-follows-window prev";
          alt-shift-l = "move-node-to-monitor --focus-follows-window next";
          alt-f = "fullscreen";
          alt-1 = "workspace 1";
          alt-2 = "workspace 2";
          alt-3 = "workspace 3";
          alt-4 = "workspace 4";
          alt-5 = "workspace 5";
          alt-6 = "workspace 6";
          alt-7 = "workspace 7";
          alt-8 = "workspace 8";
          alt-9 = "workspace 9";
          alt-0 = "workspace 10";
          alt-shift-1 = "move-node-to-workspace --focus-follows-window 1";
          alt-shift-2 = "move-node-to-workspace --focus-follows-window 2";
          alt-shift-3 = "move-node-to-workspace --focus-follows-window 3";
          alt-shift-4 = "move-node-to-workspace --focus-follows-window 4";
          alt-shift-5 = "move-node-to-workspace --focus-follows-window 5";
          alt-shift-6 = "move-node-to-workspace --focus-follows-window 6";
          alt-shift-7 = "move-node-to-workspace --focus-follows-window 7";
          alt-shift-8 = "move-node-to-workspace --focus-follows-window 8";
          alt-shift-9 = "move-node-to-workspace --focus-follows-window 9";
          alt-shift-0 = "move-node-to-workspace --focus-follows-window 10";
        };
      };
    };
  };
}
