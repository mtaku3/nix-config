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
      };
      dev = {
        docker = {
          enable = true;
          storageDriver = "zfs";
        };
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

  # Recommended for devenv
  nix.settings.trusted-users = [
    "mtaku3"
  ];

  system.stateVersion = "24.05";
}
