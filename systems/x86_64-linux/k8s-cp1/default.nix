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
        advertiseIP = "192.168.11.102";
        masterAddress = "192.168.11.102";
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

  # NetBird peers resolve cluster Services as <svc>.<ns>.k8s.mtaku3.com
  # (pushed to them as a match domain pointing at CoreDNS).
  services.kubernetes.addons.dns.aliasDomain = "k8s.mtaku3.com";

  # etcd's member was bootstrapped under the node's old address; keep the
  # name so the existing data directory still matches.
  services.etcd = {
    name = mkForce "192.168.10.102";
    initialCluster = mkForce ["192.168.10.102=https://127.0.0.1:2380"];
  };

  system.stateVersion = "25.05";
}
