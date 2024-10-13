{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.cadnano2;
in {
  options.capybara.app.desktop.cadnano2 = {
    enable = mkBoolOpt false "Whether to enable the cadnano2";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.capybara.cadnano2];
  };
}
