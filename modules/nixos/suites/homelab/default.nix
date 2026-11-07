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
    # Nothing on the LAN talks to the node directly: besides SSH from the home
    # Wi-Fi (see the ssh module) and NetBird's own WireGuard port, everything
    # arrives over NetBird or from the node's pods.
    networking.firewall.trustedInterfaces = [
      config.services.netbird.clients.wt0.interface
      "mynet" # CNI bridge: pods -> host (apiserver, kubelet, node-exporter, ...)
      "flannel.1"
    ];

    # Single node: no flannel traffic between nodes, so keep its UDP ports shut.
    services.kubernetes.flannel.openFirewallPorts = false;

    capybara = {
      suites.common = enabled;
      app.server = {
        fail2ban = enabled;
        ssh = enabled;
        kubernetes = enabled;
        netbird = enabled;
      };
    };
  };
}
