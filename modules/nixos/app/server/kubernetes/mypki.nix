{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  top = config.services.kubernetes;
  cfg = config.capybara.app.server.kubernetes;

  # Helper to shorten the secret path lookup
  # Usage: secret "ca.crt" -> config.age.secrets."/kubernetes/pki/ca.crt".path
  secret = name: config.age.secrets."homelab-k8s/${name}".path;

  # Helper to generate kubeconfig files using direct secret paths
  mkKubeConfig = name: {
    cert,
    key,
    ca ? secret "ca.crt",
    server ? top.apiserverAddress,
  }:
    top.lib.mkKubeConfig name {
      inherit server;
      certFile = cert;
      keyFile = key;
      caFile = ca;
    };

  # Define the cluster-admin kubeconfig for system usage
  clusterAdminKubeconfig = mkKubeConfig "cluster-admin" {
    cert = secret "cluster-admin-client.crt";
    key = secret "cluster-admin-client.key";
  };
in {
  config = mkIf cfg.enable {
    # 2. Etcd
    services.etcd = {
      # listenClientUrls = ["https://127.0.0.1:2379"];
      listenClientUrls = ["https://0.0.0.0:2379"];
      listenPeerUrls = ["https://127.0.0.1:2380"];
      advertiseClientUrls = ["https://${cfg.advertiseIP}:2379"];
      initialCluster = ["${top.masterAddress}=https://127.0.0.1:2380"];
      initialAdvertisePeerUrls = ["https://127.0.0.1:2380"];
      # advertiseClientUrls = ["https://etcd.local:2379"];
      # initialCluster = ["${top.masterAddress}=https://etcd.local:2380"];
      # initialAdvertisePeerUrls = ["https://etcd.local:2380"];

      certFile = secret "etcd/server.crt";
      keyFile = secret "etcd/server.key";
      peerCertFile = secret "etcd/peer.crt";
      peerKeyFile = secret "etcd/peer.key";
      trustedCaFile = secret "etcd/ca.crt";
    };

    # networking.extraHosts = mkIf (config.services.etcd.enable) ''
    #   127.0.0.1 etcd.${top.addons.dns.clusterDomain} etcd.local
    # '';

    # 3. Flannel
    services.flannel = mkIf top.flannel.enable {
      etcd = {
        certFile = secret "flannel-etcd-client.crt";
        keyFile = secret "flannel-etcd-client.key";
        caFile = secret "etcd/ca.crt";
      };

      kubeconfig = mkKubeConfig "flannel" {
        cert = secret "flannel-client.crt";
        key = secret "flannel-client.key";
      };
    };

    # 4. Kubernetes Components
    services.kubernetes = {
      caFile = secret "ca.crt";

      apiserver = mkIf top.apiserver.enable {
        etcd = {
          servers = ["https://127.0.0.1:2379"];
          # servers = ["https://etcd.local:2379"];
          certFile = secret "apiserver-etcd-client.crt";
          keyFile = secret "apiserver-etcd-client.key";
          caFile = secret "etcd/ca.crt";
        };

        clientCaFile = secret "ca.crt";
        tlsCertFile = secret "apiserver.crt";
        tlsKeyFile = secret "apiserver.key";

        serviceAccountKeyFile = secret "sa.pub";
        # sa.key might not be necessary here, but adding since nixos module asks for it
        serviceAccountSigningKeyFile = secret "sa.key";

        # kubeletClientCaFile = secret "ca.crt";
        kubeletClientCertFile = secret "apiserver-kubelet-client.crt";
        kubeletClientKeyFile = secret "apiserver-kubelet-client.key";

        proxyClientCertFile = secret "front-proxy-client.crt";
        proxyClientKeyFile = secret "front-proxy-client.key";

        extraOpts = concatStringsSep " " [
          "--requestheader-client-ca-file=${secret "front-proxy-ca.crt"}"
        ];
      };

      controllerManager = mkIf top.controllerManager.enable {
        serviceAccountKeyFile = secret "sa.key";
        rootCaFile = secret "ca.crt";
        tlsCertFile = secret "controller-manager.crt";
        tlsKeyFile = secret "controller-manager.key";

        extraOpts = let
          kubeconfig = top.lib.mkKubeConfig "kube-controller-manager" top.controllerManager.kubeconfig;
        in
          concatStringsSep " " [
            "--cluster-signing-key-file=${secret "ca.key"}"
            "--client-ca-file=${secret "ca.crt"}"
            "--cluster-signing-cert-file=${secret "ca.crt"}"
            "--requestheader-client-ca-file=${secret "front-proxy-ca.crt"}"

            "--requestheader-username-headers=X-Remote-User"
            "--requestheader-group-headers=X-Remote-Group"
            "--requestheader-extra-headers-prefix=X-Remote-Extra-"
            "--requestheader-allowed-names=front-proxy-client"

            "--authentication-kubeconfig=${kubeconfig}"
            "--authorization-kubeconfig=${kubeconfig}"
          ];

        kubeconfig = {
          certFile = secret "controller-manager-client.crt";
          keyFile = secret "controller-manager-client.key";
        };
      };

      scheduler = mkIf top.scheduler.enable {
        extraOpts = let
          kubeconfig = top.lib.mkKubeConfig "kube-scheduler" top.scheduler.kubeconfig;
        in
          concatStringsSep " " [
            "--client-ca-file=${secret "ca.crt"}"
            "--tls-cert-file=${secret "scheduler.crt"}"
            "--tls-private-key-file=${secret "scheduler.key"}"

            "--authentication-kubeconfig=${kubeconfig}"
            "--authorization-kubeconfig=${kubeconfig}"
          ];

        kubeconfig = {
          certFile = secret "scheduler-client.crt";
          keyFile = secret "scheduler-client.key";
        };
      };

      kubelet = mkIf top.kubelet.enable {
        clientCaFile = secret "ca.crt";
        tlsCertFile = secret "kubelet.crt";
        tlsKeyFile = secret "kubelet.key";

        kubeconfig = {
          certFile = secret "kubelet-client.crt";
          keyFile = secret "kubelet-client.key";
        };
      };

      proxy = mkIf top.proxy.enable {
        kubeconfig = {
          certFile = secret "kube-proxy-client.crt";
          keyFile = secret "kube-proxy-client.key";
        };
      };
    };

    # 5. Addon Manager
    systemd.services.kube-addon-manager = mkIf top.addonManager.enable (mkMerge [
      {
        environment.KUBECONFIG = mkKubeConfig "addon-manager" {
          cert = secret "addon-manager-client.crt";
          key = secret "addon-manager-client.key";
        };
      }

      (optionalAttrs (top.addonManager.bootstrapAddons != {}) {
        serviceConfig.PermissionsStartOnly = true;
        preStart = with pkgs; let
          files =
            mapAttrsToList (
              n: v: writeText "${n}.json" (builtins.toJSON v)
            )
            top.addonManager.bootstrapAddons;
        in ''
          export KUBECONFIG=${clusterAdminKubeconfig}
          ${top.package}/bin/kubectl apply -f ${concatStringsSep " \\\n -f " files}
        '';
      })
    ]);

    age.secrets = {
      # 1. Cluster Root CA
      "homelab-k8s/ca.crt" = {
        mode = "644";
        owner = "root";
        group = "kubernetes";
      };
      "homelab-k8s/ca.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 2. Cluster Admin
      "homelab-k8s/cluster-admin-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/cluster-admin-client.key" = {
        mode = "400";
        owner = "root";
        group = "kubernetes";
      };

      # 3. Etcd
      "homelab-k8s/etcd/ca.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/etcd/ca.key" = {
        mode = "400";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/etcd/server.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/etcd/server.key" = {
        mode = "400";
        owner = "etcd";
        group = "kubernetes";
      };
      "homelab-k8s/etcd/peer.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/etcd/peer.key" = {
        mode = "400";
        owner = "etcd";
        group = "kubernetes";
      };

      # 4. Flannel
      "homelab-k8s/flannel-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/flannel-client.key" = {
        mode = "400";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/flannel-etcd-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/flannel-etcd-client.key" = {
        mode = "400";
        owner = "root";
        group = "root";
      };

      # 5. API Server (Etcd Client)
      "homelab-k8s/apiserver-etcd-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/apiserver-etcd-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 6. API Server (Serving)
      "homelab-k8s/apiserver.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/apiserver.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 7. Service Accounts
      "homelab-k8s/sa.pub" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/sa.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 8. API Server (Kubelet Client)
      "homelab-k8s/apiserver-kubelet-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/apiserver-kubelet-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      "homelab-k8s/kubelet-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/kubelet-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      "homelab-k8s/kubelet.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/kubelet.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 9. API Server (Front Proxy)
      "homelab-k8s/front-proxy-ca.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/front-proxy-ca.key" = {
        mode = "400";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/front-proxy-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/front-proxy-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 10. Controller Manager
      "homelab-k8s/controller-manager-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/controller-manager-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };
      "homelab-k8s/controller-manager.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/controller-manager.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 11. Scheduler
      "homelab-k8s/scheduler-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/scheduler-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };
      "homelab-k8s/scheduler.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/scheduler.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      # 12. Addon Manager
      "homelab-k8s/addon-manager-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/addon-manager-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };

      "homelab-k8s/kube-proxy-client.crt" = {
        mode = "644";
        owner = "root";
        group = "root";
      };
      "homelab-k8s/kube-proxy-client.key" = {
        mode = "400";
        owner = "kubernetes";
        group = "kubernetes";
      };
    };
  };
}
