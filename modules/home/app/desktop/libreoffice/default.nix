{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.libreoffice;
in {
  options.capybara.app.desktop.libreoffice = {
    enable = mkBoolOpt false "Whether to enable the libreoffice";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [libreoffice];
  };
}
