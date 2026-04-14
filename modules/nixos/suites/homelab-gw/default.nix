{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.suites.homelab-gw;
in {
  options.capybara.suites.homelab-gw = with types; {
    enable = mkBoolOpt false "Whether to enable the homelab gateway suite";
    sshPort = mkOpt port 2222 "SSH port for direct access to the gateway";
    forwardTarget = mkOpt str "" "Target IP to forward traffic to (e.g. netbird IP)";
    externalInterface = mkOpt str "" "External network interface name";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.forwardTarget != "";
        message = "capybara.suites.homelab-gw.forwardTarget must be set";
      }
      {
        assertion = cfg.externalInterface != "";
        message = "capybara.suites.homelab-gw.externalInterface must be set";
      }
    ];

    capybara = {
      suites.common = enabled;
      app.server = {
        fail2ban = enabled;
        ssh = {
          enable = true;
          port = cfg.sshPort;
        };
        netbird = enabled;
      };
    };

    # Open all ports for forwarded traffic
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

    # IP forwarding
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

    # NAT
    networking.nat = {
      enable = true;
      externalInterface = cfg.externalInterface;
      internalInterfaces = ["wt0"];
    };

    # DNAT rules: forward all traffic to target except SSH and netbird ports
    networking.firewall.extraCommands = ''
      iptables -t nat -A PREROUTING -p tcp --dport ${toString cfg.sshPort} -j RETURN
      iptables -t nat -A PREROUTING -p tcp -j DNAT --to-destination ${cfg.forwardTarget}
      iptables -t nat -A PREROUTING -p udp --dport 51821 -j RETURN
      iptables -t nat -A PREROUTING -p udp -j DNAT --to-destination ${cfg.forwardTarget}
      iptables -t nat -A POSTROUTING -o wt0 -j MASQUERADE
    '';

    networking.firewall.extraStopCommands = ''
      iptables -t nat -D PREROUTING -p tcp --dport ${toString cfg.sshPort} -j RETURN 2>/dev/null || true
      iptables -t nat -D PREROUTING -p tcp -j DNAT --to-destination ${cfg.forwardTarget} 2>/dev/null || true
      iptables -t nat -D PREROUTING -p udp --dport 51821 -j RETURN 2>/dev/null || true
      iptables -t nat -D PREROUTING -p udp -j DNAT --to-destination ${cfg.forwardTarget} 2>/dev/null || true
      iptables -t nat -D POSTROUTING -o wt0 -j MASQUERADE 2>/dev/null || true
    '';
  };
}
