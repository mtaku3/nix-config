{lib, ...}:
with lib;
with lib.capybara; {
  imports = [
    ./hardware-configuration.nix
  ];

  capybara = {
    system.bluetooth = enabled;
    archetypes.workstation = enabled;

    app = {
      system = {
        blueman = enabled;
        fprintd = enabled;
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
