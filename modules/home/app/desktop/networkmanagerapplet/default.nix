{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.networkmanagerapplet;
in {
  options.capybara.app.desktop.networkmanagerapplet = {
    enable = mkBoolOpt false "Whether to enable the nm-applet";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.networkmanagerapplet];
  };
}
