{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.suites.homelab;
in {
  options.capybara.suites.homelab = with types; {
    enable = mkBoolOpt false "Whether to enable the homelab suite";
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 0;
          to = 65535;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 0;
          to = 65535;
        }
      ];
    };

    capybara = {
      suites.common = enabled;
      app.server = {
        fail2ban = enabled;
        ssh = enabled;
        kubernetes = enabled;
        tailscale = enabled;
      };
    };
  };
}
