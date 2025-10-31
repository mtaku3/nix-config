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

  boot.kernelPackages = pkgs.linuxPackages_5_15;

  capybara = {
    suites.homelab = enabled;

    app.server.kubernetes = {
      role = "master";
      advertiseIP = "192.168.10.2";
      masterAddress = "192.168.10.2";
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

  users.users.root.packages = with pkgs; [git vim curl wget];

  system.stateVersion = "25.05";
}
