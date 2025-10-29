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
      };
    };

    agenix = enabled;
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
