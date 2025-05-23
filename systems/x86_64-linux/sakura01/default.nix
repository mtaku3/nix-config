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
    suites.vps.master = enabled;

    agenix = enabled;
    impermanence = {
      enable = true;
      name = "/persist";
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/dokploy"
        "/etc/deployments"
      ];
    };
  };

  users.users.root.packages = with pkgs; [git vim curl wget];

  system.stateVersion = "24.11";
}
