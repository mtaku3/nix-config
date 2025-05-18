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

    services.libinput.touchpad = {
      naturalScrolling = true;
      disableWhileTyping = true;
      tappingDragLock = false;
    };

    capybara.xserver.autorandr = enabled;
  };
}
