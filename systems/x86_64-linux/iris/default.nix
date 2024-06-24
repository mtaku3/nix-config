{lib, ...}:
with lib;
with lib.capybara; {
  imports = [
    ./hardware-configuration.nix
  ];

  # Required for home-manager impermanence
  programs.fuse.userAllowOther = true;

  capybara = {
    system.bluetooth = enabled;
    archetypes.workstation = enabled;
    nix.devenv-cachix = enabled;

    app = {
      system = {
        blueman = enabled;
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

  system.stateVersion = "24.05";
}
