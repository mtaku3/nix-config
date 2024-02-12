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
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd startx";
          user = "greeter";
        };
      };
    };

    security.sudo.extraRules = [
      {
        commands = [
          {
            command = "${pkgs.systemd}/bin/shutdown -h now";
            options = ["NOPASSWD"];
          }
          {
            command = "${pkgs.systemd}/bin/shutdown -r now";
            options = ["NOPASSWD"];
          }
        ];
        groups = ["greeter"];
      }
    ];

    environment.systemPackages = with pkgs; [
      xorg.xinit
    ];
  };
}
