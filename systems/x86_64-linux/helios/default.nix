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
      ssh = enabled;
      fail2ban = enabled;
      netbird = enabled;
    };

    app.dev = {
      docker = enabled;
      nix-ld.enable = true;
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

  services.journald.storage = "persistent";

  users.users.root.packages = with pkgs; [git vim curl wget];

  system.stateVersion = "25.05";
}
