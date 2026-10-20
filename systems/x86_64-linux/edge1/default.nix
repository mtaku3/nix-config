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

    app.server = {
      # Host sshd moves off 22: the public :22 belongs to Warpgate.
      ssh = {
        enable = true;
        port = 2222;
      };
      fail2ban = enabled;
      docker = enabled;

      pangolin = {
        enable = true;
        baseDomain = "mtaku3.com";
        acmeEmail = "certificates@mtaku3.com";
        # Raw TCP resources Warpgate chains into (one per SSH target).
        tcpPorts = [2201 2202 2203 2204];
      };

      warpgate = {
        enable = true;
        externalHost = "warpgate.mtaku3.com";
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
