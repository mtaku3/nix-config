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

      # Passkey-only OIDC provider for the homelab, at id.mtaku3.com.
      pocket-id = enabled;

      warpgate = {
        enable = true;
        externalHost = "warpgate.mtaku3.com";
        # SSH and the web UI are published through the NetBird reverse proxy.
        pocketId.clientId = "0e0c333d-a939-4079-b0a4-ab9e0877f95f";
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

  users.users.root.packages = with pkgs; [git vim curl wget];

  system.stateVersion = "25.05";
}
