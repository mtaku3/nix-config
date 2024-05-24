{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  xmonadEnabled = foldl (acc: config: acc || config.capybara.desktop.xserver.windowManager.xmonad.enable) false (attrValues (userConfigs config));
in {
  config = mkIf xmonadEnabled (let
    createDesktopEntry = {
      name,
      script,
    }:
      pkgs.writeTextFile {
        name = "${name}-xsession";
        destination = "/share/xsessions/${name}.desktop";
        text = ''
          [Desktop Entry]
          Version=1.0
          Type=XSession
          Exec=${script}
          Name=${name}
        '';
      };
    sessions = [
      {
        name = "XMonad";
        script = "startx $HOME/.xinitrc xmonad";
      }
    ];
  in {
    environment = {
      systemPackages = map createDesktopEntry sessions ++ [pkgs.xmonad-with-packages];
      pathsToLink = ["/share/xsessions"];
    };
  });
}
