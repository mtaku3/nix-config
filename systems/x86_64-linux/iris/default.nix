{lib, ...}:
with lib;
with lib.capybara; {
  imports = [
    ./hardware-configuration.nix
  ];

  # Required for home-manager impermanence
  programs.fuse.userAllowOther = true;

  # Secrets management
  age = {
    identityPaths = ["/persist/var/lib/agenix/agenix_ed25519"];
    secrets = {
      "users/mtaku3/password".file = snowfall.fs.get-snowfall-file "secrets/users/mtaku3@iris/password.age";
    };
  };

  capybara = {
    system.bluetooth = enabled;
    app.blueman = enabled;
    archetypes.workstation = enabled;
    nix.devenv-cachix = enabled;

    app.docker = enabled;
  };

  environment.persistence."/persist" = {
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/docker"
    ];
    files = [
      "/var/lib/agenix/agenix_ed25519"
    ];
  };

  system.stateVersion = "24.05";
}
