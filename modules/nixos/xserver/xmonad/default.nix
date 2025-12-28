{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  xmonad-enabled = users-any (cfg: cfg.capybara.xserver.windowManager.xmonad.enable) config;
in {
  config = mkIf xmonad-enabled {
    capybara.greetd.xsessions = [
      {
        name = "XMonad";
        script = "startx $HOME/.xinitrc xmonad";
      }
    ];
  };
}
