{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.kubernetes;
in {
  options.capybara.app.server.kubernetes = with types; {
    enable = mkBoolOpt false "Whether to enable the kubernetes";
    advertiseIP = mkOpt types.str "" "IP address to advertise for the Kubernetes API server";
    masterAddress = mkOpt types.str "" "IP address or hostname of the Kubernetes master node";
    role = mkOpt (types.enum ["master" "node"]) "node" "Role of the Kubernetes node";
  };

  config = mkIf cfg.enable {
    virtualisation.containerd.settings.plugins."io.containerd.grpc.v1.cri".containerd.snapshotter = "overlayfs";

    services.kubernetes = let
      api = "https://${cfg.masterAddress}:6443";
    in
      mkMerge [
        {
          masterAddress = cfg.masterAddress;
          apiserverAddress = api;
          easyCerts = true;

          apiserver.allowPrivileged = true;

          addons.dns = enabled;
        }
        (optionalAttrs (cfg.role == "master") {
          roles = ["master" "node"];
          apiserver = {
            securePort = 6443;
            advertiseAddress = cfg.advertiseIP;
          };
        })
        (optionalAttrs (cfg.role == "node") {
          roles = ["node"];
          kubelet.kubeconfig.server = api;
        })
      ];

    capybara.impermanence.directories = [
      {
        directory = "/var/lib/cfssl";
        user = "cfssl";
        group = "cfssl";
        mode = "0700";
      }
      {
        directory = "/var/lib/containerd";
        user = "root";
        group = "root";
        mode = "0755";
      }
      {
        directory = "/var/lib/etcd";
        user = "etcd";
        group = "root";
        mode = "0700";
      }
      {
        directory = "/var/lib/kubelet";
        user = "root";
        group = "root";
        mode = "0755";
      }
      {
        directory = "/var/lib/kubernetes";
        user = "kubernetes";
        group = "kubernetes";
        mode = "0755";
      }
      {
        directory = "/var/lib/cni";
        user = "root";
        group = "root";
        mode = "0600";
      }
    ];
  };
}
