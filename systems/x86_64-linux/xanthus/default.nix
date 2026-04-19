{lib, ...}:
with lib;
with lib.capybara; {
  imports = [
    ./hardware-configuration.nix
  ];

  capybara = {
    system = {
      bluetooth = enabled;
      power.do-not-sleep = enabled;
    };
    archetypes.workstation = enabled;
    xserver.xrdp = enabled;

    app = {
      system = {
        blueman = enabled;
        fprintd = enabled;
        thunderbolt = enabled;
        wireguard = enabled;
      };
      dev = {
        docker = enabled;
        nix-ld = enabled;
      };
    };

    agenix = {
      enable = true;
      hostPubkeys = [
        "age1wlq6zv0jetvl2pq2qartxc5vwexj23yv2qmmps7cw32a52qy0qsssrwfqp"
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

  system.stateVersion = "24.11";
}
