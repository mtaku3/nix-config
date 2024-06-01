{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.gimp;
in {
  options.capybara.app.desktop.gimp = {
    enable = mkBoolOpt false "Whether to enable the gimp";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [gimp];
  };
}
