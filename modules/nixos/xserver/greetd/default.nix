{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.xserver.greetd;
in {
  options.capybara.xserver.greetd = {
    enable = mkBoolOpt false "Whether to enable the greetd";
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      vt = 2;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet -x /run/current-system/sw/share/xsessions --no-xsession-wrapper --remember-session --power-shutdown 'sudo shutdown -h now' --power-reboot 'sudo shutdown -r now'";
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

    capybara.impermanence.directories = ["/var/cache/tuigreet"];
  };
}
