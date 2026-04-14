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
    suites.homelab-gw = {
      enable = true;
      sshPort = 2222;
      forwardTarget = "100.83.165.61";
      externalInterface = "ens3";
    };

    agenix = enabled;
  };

  nix.settings.trusted-users = ["mtaku3"];

  services.journald = {
    storage = "persistent";
    extraConfig = ''
      SystemMaxUse=200M
      MaxRetentionSec=1week
    '';
  };

  users.users.root = {
    packages = with pkgs; [git vim curl wget];
  };

  system.stateVersion = "25.05";
}
