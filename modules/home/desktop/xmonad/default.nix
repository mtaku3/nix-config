{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.xmonad;
in {
  options.capybara.desktop.xmonad = {
    enable = mkBoolOpt false "Whether to enable the XMonad";
  };

  config = mkIf cfg.enable {
    xsession = {
      enable = true;
      windowManager.xmonad = enabled;
    };
  };
}
