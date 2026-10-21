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
    suites.homelab = enabled;
    # NetBird pushes per-domain DNS to resolved; resolvconf mode fails under the hardened daemon.
    system.network.resolved = true;

    app.server = {
      kubernetes = {
        role = "master";
        advertiseIP = "192.168.10.102";
        masterAddress = "192.168.10.102";
        kube-vip = {
          enable = true;
          interface = "ens18";
          address = "192.168.10.100";
        };
      };
    };

    app.dev.nix-ld.enable = true;

    agenix = {
      enable = true;
      hostPubkeys = [
        "age1xcjwq56825tfcf8hncvleteppwlzya542kc5lfauwpest9g65qpqv0a6kn"
      ];
    };
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

  nix.settings.trusted-users = ["mtaku3"];

  # Warpgate on edge1 logs in as mtaku3 on behalf of SSO-authenticated users.
  users.users.mtaku3.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBznGw/YMlO4fQVApPr86pcaednatPJ+r+eDT4JRC6Ho warpgate@edge1"
  ];

  users.users.root.packages = with pkgs; [git vim curl wget];

  system.stateVersion = "25.05";
}
