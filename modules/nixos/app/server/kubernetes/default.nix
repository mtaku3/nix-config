{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.kubernetes;
  api = "https://${cfg.masterAddress}:6443";
in {
  # disabledModules = [
  #   "services/cluster/kubernetes/pki.nix"
  #   "services/cluster/kubernetes/apiserver.nix"
  #   "services/cluster/kubernetes/controller-manager.nix"
  #   "services/cluster/kubernetes/flannel.nix"
  #   "services/cluster/kubernetes/kubelet.nix"
  #   "services/cluster/kubernetes/proxy.nix"
  # ];
  #
  imports = [
    #   ./pki.nix
    #   ./apiserver.nix
    #   ./controller-manager.nix
    #   ./flannel.nix
    #   ./kubelet.nix
    #   ./proxy.nix
    ./mypki.nix
  ];

  options.capybara.app.server.kubernetes = with types; {
    enable = mkBoolOpt false "Whether to enable the kubernetes";
    advertiseIP = mkOpt types.str "" "IP address to advertise for the Kubernetes API server";
    masterAddress = mkOpt types.str "" "IP address or hostname of the Kubernetes master node";
    role = mkOpt (types.enum ["master" "node"]) "node" "Role of the Kubernetes node";
    etcdEndpoints = mkOpt (types.listOf types.str) [] "List of etcd endpoints";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      services.kubernetes = {
        masterAddress = cfg.masterAddress;
        apiserverAddress = api;
        easyCerts = false;

        apiserver.allowPrivileged = true;

        addons.dns = enabled;

        dataDir = "/var/lib/kubelet";
      };

      virtualisation.containerd.settings.plugins."io.containerd.grpc.v1.cri".containerd.snapshotter = "overlayfs";

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
          user = "kubernetes";
          group = "kubernetes";
          mode = "0755";
        }
      ];
    }
    (mkIf (cfg.role == "master") {
      services.kubernetes = {
        roles = ["master" "node"];
        apiserver = {
          securePort = 6443;
          advertiseAddress = cfg.advertiseIP;
        };
      };
    })
    (mkIf (cfg.role == "node") {
      services.kubernetes = {
        roles = ["node"];
        kubelet.kubeconfig.server = api;
      };
    })
  ]);
}
