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

    # IP forwarding
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
    };

    # NAT and DNAT rules: forward all traffic to target except SSH and netbird ports
    networking.nftables = {
      enable = true;
      tables.homelab-gw = {
        family = "ip";
        content = ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            tcp dport ${toString cfg.sshPort} accept
            udp dport 51821 accept
            tcp dport != ${toString cfg.sshPort} dnat to ${cfg.forwardTarget}
            udp dport != 51821 dnat to ${cfg.forwardTarget}
          }

          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            oifname "nb-wt0" masquerade
          }
        '';
      };
    };
  };
}
