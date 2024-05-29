{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.xserver;
in {
  options.capybara.xserver = {
    enable = mkBoolOpt false "Whether to enable the xserver";
  };

  config = mkIf cfg.enable {
    services.xserver = {
      enable = true;
      exportConfiguration = true;
    };
    environment.systemPackages = with pkgs; [xorg.xinit];

    services.xserver.libinput.touchpad.naturalScrolling = true;
  };
}
