{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.greetd;
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
in {
  options.capybara.greetd = {
    enable = mkBoolOpt false "Whether to enable the greetd";
    xsessions = mkOption {
      description = "List of xsessions to create desktop entries for";
      default = [];
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            example = "XMonad";
            description = "The display name of the session.";
          };
          script = lib.mkOption {
            type = lib.types.str;
            example = "startx $HOME/.xinitrc xmonad";
            description = "The command to execute when the session starts.";
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet -x /run/current-system/sw/share/xsessions --no-xsession-wrapper --remember-session --power-shutdown 'sudo shutdown -h now' --power-reboot 'sudo shutdown -r now'";
          user = "greeter";
        };
      };
    };

    security.sudo = {
      extraRules = [
        {
          users = ["greeter"];
          commands = [
            {
              command = "/run/current-system/sw/bin/shutdown";
              options = ["NOPASSWD"];
            }
          ];
        }
      ];
    };

    environment.systemPackages = map createDesktopEntry cfg.xsessions;
    environment.pathsToLink = ["/share/xsessions"];

    capybara.impermanence.directories = ["/var/cache/tuigreet"];
  };
}
