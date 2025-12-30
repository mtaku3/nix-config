{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  icons = pkgs.stdenv.mkDerivation {
    name = "wlogout-icons";
    src = ./wlogout-icons;

    installPhase = ''
      mkdir -p $out/share/wlogout/icons
      cp *.svg $out/share/wlogout/icons/
    '';
  };
in {
  config = {
    programs.wlogout = {
      enable = true;

      layout = [
        {
          label = "lock";
          action = "loginctl lock-session";
          text = "Lock";
          keybind = "l";
        }
        {
          label = "hibernate";
          action = "systemctl hibernate";
          text = "Hibernate";
          keybind = "h";
        }
        {
          label = "logout";
          action = "loginctl terminate-user $USER";
          text = "Exit";
          keybind = "e";
        }
        {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Power off";
          keybind = "p";
        }
        {
          label = "suspend";
          action = "systemctl suspend";
          text = "Suspend";
          keybind = "s";
        }
        {
          label = "reboot";
          action = "systemctl reboot";
          text = "Reboot";
          keybind = "r";
        }
      ];

      style = ''
        * {
          all: unset;
        }

        window {
          font-family: JetBrainsMonoNerdFont;
          font-weight: bold;
          font-size: 15pt;
          color: #f2f4f8;
          background-color: rgba(0, 0, 0, 0);
        }

        button {
          background-repeat: no-repeat;
          background-position: center;
          background-size: 25%;
          border: none;
          background-color: rgba(22, 22, 22, 1);
          margin: 18px;
          padding: 0px;
          border-radius: 30px;
          outline: none;
          transition: box-shadow 0.2s ease-in-out, background-color 0.2s ease-in-out;
        }

        button:focus {
          background-color: #cba6f7;
          color: #1e1e2e;
        }

        button:hover {
          background-color: #b78aff;
          color: #1e1e2e;
        }

        #lock {
          background-image: url("${icons}/share/wlogout/icons/lock_light.svg");
        }
        #lock:focus, #lock:hover {
          background-image: url("${icons}/share/wlogout/icons/lock_dark.svg");
        }

        #logout {
          background-image: url("${icons}/share/wlogout/icons/logout_light.svg");
        }
        #logout:focus, #logout:hover {
          background-image: url("${icons}/share/wlogout/icons/logout_dark.svg");
        }

        #suspend {
          background-image: url("${icons}/share/wlogout/icons/suspend_light.svg");
        }
        #suspend:focus, #suspend:hover {
          background-image: url("${icons}/share/wlogout/icons/suspend_dark.svg");
        }

        #shutdown {
          background-image: url("${icons}/share/wlogout/icons/shutdown_light.svg");
        }
        #shutdown:focus, #shutdown:hover {
          background-image: url("${icons}/share/wlogout/icons/shutdown_dark.svg");
        }

        #reboot {
          background-image: url("${icons}/share/wlogout/icons/reboot_light.svg");
        }
        #reboot:focus, #reboot:hover {
          background-image: url("${icons}/share/wlogout/icons/reboot_dark.svg");
        }

        #hibernate {
          background-image: url("${icons}/share/wlogout/icons/hibernate_light.svg");
        }
        #hibernate:focus, #hibernate:hover {
          background-image: url("${icons}/share/wlogout/icons/hibernate_dark.svg");
        }
      '';
    };
  };
}
