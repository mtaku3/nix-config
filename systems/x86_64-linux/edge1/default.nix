{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  imports = [
    ./hardware-configuration.nix
  ];

  capybara = {
    suites.common = enabled;
    # NetBird pushes per-domain DNS to resolved; resolvconf mode fails under the hardened daemon.
    system.network.resolved = true;

    app.server = {
      # Host sshd moves off 22: the public :22 belongs to Warpgate.
      ssh = {
        enable = true;
        port = 2222;
      };
      fail2ban = enabled;
      docker = enabled;
      # edge1's own peer, so Warpgate (a peer of its own) can SSH into edge1.
      netbird = enabled;

      netbird-server = {
        enable = true;
        baseDomain = "mtaku3.com";
        acmeEmail = "certificates@mtaku3.com";
        proxy = {
          enable = true;
          # Warpgate SSH, published as a NetBird L4 service (warpgate peer :2222).
          tcpPorts = [22];
          crowdsec = true;
        };
      };

      warpgate = {
        enable = true;
        externalHost = "warpgate.mtaku3.com";
        # SSH and the web UI are published through the NetBird reverse proxy.
        google.clientId = "810915113976-7rt2jve5vpn2d6vhd5v7d0ij9adm52bg.apps.googleusercontent.com";
      };
    };

    agenix = {
      enable = true;
      hostPubkeys = [
        "age168cz2tgx4jzkewlxtmtctpgxean6keamxmyz6nty8ldr73e7wg3sq2l7v5"
      ];
    };
    impermanence = {
      enable = true;
      name = "/persist";
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
      ];
    };
  };

  services.journald.storage = "persistent";

  nix.settings.trusted-users = ["mtaku3"];

  # Inspect the edge containers and their logs without sudo.
  users.users.mtaku3.extraGroups = ["docker" "systemd-journal"];

  # Warpgate on edge1 logs in as mtaku3 on behalf of SSO-authenticated users.
  users.users.mtaku3.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBznGw/YMlO4fQVApPr86pcaednatPJ+r+eDT4JRC6Ho warpgate@edge1"
  ];

  users.users.root.packages = with pkgs; [git vim curl wget];

  system.stateVersion = "25.05";
}
