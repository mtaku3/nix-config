{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.netbird;
in {
  options.capybara.app.server.netbird = with types; {
    enable = mkBoolOpt false "Whether to enable the netbird";
  };

  config = mkIf cfg.enable {
    services.netbird = {
      clients.wt0 = {
        # Port used to listen to wireguard connections
        port = 51821;

        # Set this to true if you want the GUI client
        ui.enable = false;

        # This opens ports required for direct connection without a relay
        openFirewall = true;

        # This opens necessary firewall ports in the Netbird client's network interface
        openInternalFirewall = true;
      };
    };

    capybara.impermanence.directories = [
      "/var/lib/netbird-wt0"
    ];
  };
}
