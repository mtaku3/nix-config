{lib, ...}:
with lib;
with lib.capybara; {
  imports = [
    ./hardware-configuration.nix
  ];

  capybara = {
    suites.vps.master = enabled;

    app = {
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
