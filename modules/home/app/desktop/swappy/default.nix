{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.swappy;
in {
  options.capybara.app.desktop.swappy = {
    enable = mkBoolOpt false "Whether to enable the swappy";
  };

  config = mkIf cfg.enable {
    programs.swappy = {
      enable = true;
      settings = {
        Default = {
          save_dir = "$HOME/Pictures/Screenshots";
          save_filename_format = "swappy-%Y%m%d-%H%M%S.png";
          show_panel = false;
          line_size = 5;
          text_size = 20;
          text_font = "JetBrains Mono Nerd Font";
          paint_mode = "brush";
          early_exit = true;
          fill_shape = false;
        };
      };
    };

    home.packages = with pkgs.unstable; [
      grim
      slurp
      wl-clipboard
    ];
  };
}
