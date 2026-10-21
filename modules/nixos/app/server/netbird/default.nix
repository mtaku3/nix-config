{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.netbird;
  setupKey = "netbird/setup-key";
in {
  options.capybara.app.server.netbird = with types; {
    enable = mkBoolOpt false "Whether to enable the netbird";
    managementUrl = mkOpt str "https://netbird.mtaku3.com" "Management server the client registers with";
    autoLogin = mkOpt bool (config.age.secrets ? ${setupKey}) "Whether to log in with the ${setupKey} agenix secret when the client needs login (on by default once the host has one)";
    routing = mkOpt (enum ["none" "client" "server" "both"]) "none" "Kernel settings for NetBird routing (see services.netbird.useRoutingFeatures)";
  };

  config = mkIf cfg.enable {
    services.netbird = {
      # Track the self-hosted server more closely than the stable channel does.
      package = pkgs.unstable.netbird;
      useRoutingFeatures = cfg.routing;

      clients.wt0 = {
        # Port used to listen to wireguard connections
        port = 51821;

        # Set this to true if you want the GUI client
        ui.enable = false;

        # This opens ports required for direct connection without a relay
        openFirewall = true;

        # This opens necessary firewall ports in the Netbird client's network interface
        openInternalFirewall = true;

        # Picked up by `netbird up`, including the login unit below.
        environment.NB_MANAGEMENT_URL = cfg.managementUrl;

        login = mkIf cfg.autoLogin {
          enable = true;
          setupKeyFile = config.age.secrets.${setupKey}.path;
        };
      };
    };

    capybara.impermanence.directories = [
      "/var/lib/netbird-wt0"
    ];
  };
}
