{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.kitty;
in {
  options.capybara.desktop.kitty = {
    enable = mkBoolOpt false "Whether to enable the kitty";
  };

  config = mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono NF";
        size = 12;
      };
      extraConfig = ''
        background_opacity 0.6
      '';
    };
  };
}
