{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.zoom-us;
in {
  options.capybara.app.desktop.zoom-us = {
    enable = mkBoolOpt false "Whether to enable the zoom-us";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.zoom-us];
    capybara.impermanence.directories = [".cache/zoom"];
  };
}
