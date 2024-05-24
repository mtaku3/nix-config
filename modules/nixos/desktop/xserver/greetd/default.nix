{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.xserver.greetd;
in {
  options.capybara.desktop.xserver.greetd = {
    enable = mkBoolOpt false "Whether to enable the greetd";
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      vt = 2;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet -s /run/current-system/sw/share/xsessions --power-shutdown 'sudo shutdown -h now' --power-reboot 'sudo shutdown -r now'";
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
  };
}
