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
      # Peer for Warpgate's SSH targets, reached by their NetBird IPs.
      netbird = enabled;

      netbird-server = {
        enable = true;
        baseDomain = "mtaku3.com";
        acmeEmail = "certificates@mtaku3.com";
        # Served by the edge Traefik itself rather than the NetBird proxy.
        httpRoutes."warpgate.mtaku3.com" = "https://warpgate:8888";
      };

      warpgate = {
        enable = true;
        externalHost = "warpgate.mtaku3.com";
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

  users.users.root.packages = with pkgs; [git vim curl wget];

  system.stateVersion = "25.05";
}
