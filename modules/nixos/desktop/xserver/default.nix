{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.xserver;
in {
  options.capybara.desktop.xserver = {
    enable = mkBoolOpt false "Whether to enable the xserver";
  };

  config = mkIf cfg.enable {
    services.xserver = {
      enable = true;
      exportConfiguration = true;
    };
    environment.systemPackages = with pkgs; [xorg.xinit];
  };
}
