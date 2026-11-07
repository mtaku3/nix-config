{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.ssh;
  netbird = config.capybara.app.server.netbird;
  netbirdInterface = config.services.netbird.clients.wt0.interface;
in {
  options.capybara.app.server.ssh = with types; {
    enable = mkBoolOpt false "Whether to enable the ssh";
    port = mkOpt types.port 22 "SSH port to listen on";
    homeNetwork = mkOpt str "192.168.20.0/24" "Home Wi-Fi network; the only place the personal key is accepted from";
    personalKey = mkOpt str "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE2Qo8sbL84Lqy6SEZThrtVcIK5nplmqqDD7iBG1vLYc" "Public half of the personal key kept in 1Password";
    warpgateKey = mkOpt str "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBznGw/YMlO4fQVApPr86pcaednatPJ+r+eDT4JRC6Ho warpgate@edge1" "Warpgate's client key, used for SSO-authenticated sessions";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = netbird.enable;
        message = "capybara.app.server.ssh: Warpgate reaches hosts over NetBird, so capybara.app.server.netbird must be enabled";
      }
    ];

    # The only two keys: the personal key from the home Wi-Fi, and Warpgate's
    # key from NetBird. Everything else reaches a host through Warpgate.
    users.users.mtaku3.openssh.authorizedKeys.keys = [
      ''from="${cfg.homeNetwork}" ${cfg.personalKey}''
      ''from="${concatStringsSep "," netbird.peerRanges}" ${cfg.warpgateKey}''
    ];

    # sshd is reachable from the home Wi-Fi and from NetBird only.
    networking.firewall = {
      interfaces.${netbirdInterface}.allowedTCPPorts = [cfg.port];
      extraCommands = ''
        iptables -A nixos-fw -p tcp -s ${cfg.homeNetwork} --dport ${toString cfg.port} -j nixos-fw-accept
      '';
    };

    services.openssh = {
      enable = true;
      openFirewall = false;
      ports = [cfg.port];
      settings = {
        PasswordAuthentication = false;
        AllowUsers = null;
        UseDns = true;
        X11Forwarding = false;
        PermitRootLogin = "no";
        # sshd's own per-source penalties would likewise refuse Warpgate's
        # peer (and so every user) after a few failed logins; see fail2ban.
        PerSourcePenaltyExemptList = concatStringsSep "," config.capybara.app.server.netbird.peerRanges;
      };
    };

    age.secrets = {
      "ssh/ssh_host_rsa_key" = {
        path = "/etc/ssh/ssh_host_rsa_key";
        mode = "600";
        owner = "root";
        group = "root";
      };
      "ssh/ssh_host_rsa_key.pub" = {
        path = "/etc/ssh/ssh_host_rsa_key.pub";
        mode = "644";
        owner = "root";
        group = "root";
      };
      "ssh/ssh_host_ed25519_key" = {
        path = "/etc/ssh/ssh_host_ed25519_key";
        mode = "600";
        owner = "root";
        group = "root";
      };
      "ssh/ssh_host_ed25519_key.pub" = {
        path = "/etc/ssh/ssh_host_ed25519_key.pub";
        mode = "644";
        owner = "root";
        group = "root";
      };
    };
  };
}
