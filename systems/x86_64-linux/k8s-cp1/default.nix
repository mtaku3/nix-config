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

  # DRBD 9.2.16 (Piraeus) doesn't build against 26.05's default 6.18 kernel;
  # stay on the 6.12 LTS line it builds against.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # nixos-26.05 ships Kubernetes 1.36, but the control plane may only move one
  # minor at a time. Hold 1.35 until the cluster has run on it, then drop this.
  services.kubernetes.package = pkgs.kubernetes.overrideAttrs (finalAttrs: _: {
    version = "1.35.9";
    src = pkgs.fetchFromGitHub {
      owner = "kubernetes";
      repo = "kubernetes";
      tag = "v${finalAttrs.version}";
      hash = "sha256-y7GR3hDcWiFBbpJBAGTsTM70jqo7jss4Flqb9udhnCs=";
    };
  });

  # etcd's member was bootstrapped under the node's old address; keep the
  # name so the existing data directory still matches.
  services.etcd = {
    name = mkForce "192.168.10.102";
    initialCluster = mkForce ["192.168.10.102=https://127.0.0.1:2380"];
  };

  system.stateVersion = "25.05";
}
