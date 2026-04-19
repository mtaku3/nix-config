{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  top = config.services.kubernetes;
  cfg = config.capybara.app.server.kubernetes;
  pki = lib.capybara.k8s-pki.specs;

  # Shared CAs + SA keypair
  ca = name: config.age.secrets."common/k8s-pki/${name}".path;
  # Per-host operational leaves
  host = name: config.age.secrets."homelab-k8s/${name}".path;

  mkKubeConfig = name: {
    cert,
    key,
    caFile ? ca "ca.crt",
    server ? top.apiserverAddress,
  }:
    top.lib.mkKubeConfig name {
      inherit server;
      certFile = cert;
      keyFile = key;
      inherit caFile;
    };

  clusterAdminKubeconfig = mkKubeConfig "cluster-admin" {
    cert = host "cluster-admin-client.crt";
    key = host "cluster-admin-client.key";
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

      certFile = host "etcd/server.crt";
      keyFile = host "etcd/server.key";
      peerCertFile = host "etcd/peer.crt";
      peerKeyFile = host "etcd/peer.key";
      trustedCaFile = ca "etcd/ca.crt";
    };

    # networking.extraHosts = mkIf (config.services.etcd.enable) ''
    #   127.0.0.1 etcd.${top.addons.dns.clusterDomain} etcd.local
    # '';

    # 3. Flannel
    services.flannel = mkIf top.flannel.enable {
      etcd = {
        certFile = host "flannel-etcd-client.crt";
        keyFile = host "flannel-etcd-client.key";
        caFile = ca "etcd/ca.crt";
      };

      kubeconfig = mkKubeConfig "flannel" {
        cert = host "flannel-client.crt";
        key = host "flannel-client.key";
      };
    };

    # 4. Kubernetes Components
    services.kubernetes = {
      caFile = ca "ca.crt";

      apiserver = mkIf top.apiserver.enable {
        etcd = {
          servers = ["https://127.0.0.1:2379"];
          # servers = ["https://etcd.local:2379"];
          certFile = host "apiserver-etcd-client.crt";
          keyFile = host "apiserver-etcd-client.key";
          caFile = ca "etcd/ca.crt";
        };

        clientCaFile = ca "ca.crt";
        tlsCertFile = host "apiserver.crt";
        tlsKeyFile = host "apiserver.key";

        serviceAccountKeyFile = ca "sa.pub";
        # sa.key might not be necessary here, but adding since nixos module asks for it
        serviceAccountSigningKeyFile = ca "sa.key";

        # kubeletClientCaFile = ca "ca.crt";
        kubeletClientCertFile = host "apiserver-kubelet-client.crt";
        kubeletClientKeyFile = host "apiserver-kubelet-client.key";

        proxyClientCertFile = host "front-proxy-client.crt";
        proxyClientKeyFile = host "front-proxy-client.key";

        extraOpts = concatStringsSep " " [
          "--requestheader-client-ca-file=${ca "front-proxy-ca.crt"}"
        ];
      };

      controllerManager = mkIf top.controllerManager.enable {
        serviceAccountKeyFile = ca "sa.key";
        rootCaFile = ca "ca.crt";
        tlsCertFile = host "controller-manager.crt";
        tlsKeyFile = host "controller-manager.key";

        extraOpts = let
          kubeconfig = top.lib.mkKubeConfig "kube-controller-manager" top.controllerManager.kubeconfig;
        in
          concatStringsSep " " [
            "--cluster-signing-key-file=${ca "ca.key"}"
            "--client-ca-file=${ca "ca.crt"}"
            "--cluster-signing-cert-file=${ca "ca.crt"}"
            "--requestheader-client-ca-file=${ca "front-proxy-ca.crt"}"

            "--requestheader-username-headers=X-Remote-User"
            "--requestheader-group-headers=X-Remote-Group"
            "--requestheader-extra-headers-prefix=X-Remote-Extra-"
            "--requestheader-allowed-names=front-proxy-client"

            "--authentication-kubeconfig=${kubeconfig}"
            "--authorization-kubeconfig=${kubeconfig}"
          ];

        kubeconfig = {
          certFile = host "controller-manager-client.crt";
          keyFile = host "controller-manager-client.key";
        };
      };

      scheduler = mkIf top.scheduler.enable {
        extraOpts = let
          kubeconfig = top.lib.mkKubeConfig "kube-scheduler" top.scheduler.kubeconfig;
        in
          concatStringsSep " " [
            "--client-ca-file=${ca "ca.crt"}"
            "--tls-cert-file=${host "scheduler.crt"}"
            "--tls-private-key-file=${host "scheduler.key"}"

            "--authentication-kubeconfig=${kubeconfig}"
            "--authorization-kubeconfig=${kubeconfig}"
          ];

        kubeconfig = {
          certFile = host "scheduler-client.crt";
          keyFile = host "scheduler-client.key";
        };
      };

      kubelet = mkIf top.kubelet.enable {
        clientCaFile = ca "ca.crt";
        tlsCertFile = host "kubelet.crt";
        tlsKeyFile = host "kubelet.key";

        kubeconfig = {
          certFile = host "kubelet-client.crt";
          keyFile = host "kubelet-client.key";
        };
      };

      proxy = mkIf top.proxy.enable {
        kubeconfig = {
          certFile = host "kube-proxy-client.crt";
          keyFile = host "kube-proxy-client.key";
        };
      };
    };

    # 5. Addon Manager
    systemd.services.kube-addon-manager = mkIf top.addonManager.enable (mkMerge [
      {
        environment.KUBECONFIG = mkKubeConfig "addon-manager" {
          cert = host "addon-manager-client.crt";
          key = host "addon-manager-client.key";
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

    age.secrets = let
      hostEntries = {
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
        "homelab-k8s/etcd/healthcheck-client.crt" = {
          mode = "644";
          owner = "root";
          group = "root";
        };
        "homelab-k8s/etcd/healthcheck-client.key" = {
          mode = "400";
          owner = "root";
          group = "root";
        };
      };
      commonEntries = {
        "common/k8s-pki/ca.crt" = {
          mode = "644";
          owner = "root";
          group = "kubernetes";
        };
        "common/k8s-pki/ca.key" = {
          mode = "400";
          owner = "kubernetes";
          group = "kubernetes";
        };
        "common/k8s-pki/etcd/ca.crt" = {
          mode = "644";
          owner = "root";
          group = "root";
        };
        "common/k8s-pki/etcd/ca.key" = {
          mode = "400";
          owner = "root";
          group = "root";
        };
        "common/k8s-pki/front-proxy-ca.crt" = {
          mode = "644";
          owner = "root";
          group = "root";
        };
        "common/k8s-pki/front-proxy-ca.key" = {
          mode = "400";
          owner = "root";
          group = "root";
        };
        "common/k8s-pki/sa.pub" = {
          mode = "644";
          owner = "root";
          group = "root";
        };
        "common/k8s-pki/sa.key" = {
          mode = "400";
          owner = "kubernetes";
          group = "kubernetes";
        };
      };
    in
      hostEntries // commonEntries;

    systemd.services.kube-apiserver.restartTriggers = [
      config.age.secrets."common/k8s-pki/ca.crt".file
      config.age.secrets."homelab-k8s/apiserver.crt".file
      config.age.secrets."homelab-k8s/apiserver-kubelet-client.crt".file
      config.age.secrets."homelab-k8s/apiserver-etcd-client.crt".file
      config.age.secrets."homelab-k8s/front-proxy-client.crt".file
      config.age.secrets."common/k8s-pki/sa.pub".file
      config.age.secrets."common/k8s-pki/sa.key".file
      config.age.secrets."common/k8s-pki/front-proxy-ca.crt".file
      config.age.secrets."common/k8s-pki/etcd/ca.crt".file
    ];
    systemd.services.kube-controller-manager.restartTriggers = [
      config.age.secrets."common/k8s-pki/ca.crt".file
      config.age.secrets."homelab-k8s/controller-manager.crt".file
      config.age.secrets."homelab-k8s/controller-manager-client.crt".file
      config.age.secrets."common/k8s-pki/ca.key".file
      config.age.secrets."common/k8s-pki/sa.key".file
    ];
    systemd.services.kube-scheduler.restartTriggers = [
      config.age.secrets."common/k8s-pki/ca.crt".file
      config.age.secrets."homelab-k8s/scheduler.crt".file
      config.age.secrets."homelab-k8s/scheduler-client.crt".file
    ];
    systemd.services.kubelet.restartTriggers = [
      config.age.secrets."common/k8s-pki/ca.crt".file
      config.age.secrets."homelab-k8s/kubelet.crt".file
      config.age.secrets."homelab-k8s/kubelet-client.crt".file
    ];
    systemd.services.kube-proxy.restartTriggers = [
      config.age.secrets."common/k8s-pki/ca.crt".file
      config.age.secrets."homelab-k8s/kube-proxy-client.crt".file
    ];
    systemd.services.flannel.restartTriggers = [
      config.age.secrets."common/k8s-pki/ca.crt".file
      config.age.secrets."homelab-k8s/flannel-client.crt".file
      config.age.secrets."homelab-k8s/flannel-etcd-client.crt".file
    ];
    systemd.services.etcd.restartTriggers = [
      config.age.secrets."homelab-k8s/etcd/server.crt".file
      config.age.secrets."homelab-k8s/etcd/peer.crt".file
      config.age.secrets."common/k8s-pki/etcd/ca.crt".file
    ];

    assertions = let
      caNames = attrNames pki.cas;
      hostLeafNames = attrNames pki.leaves;
    in [
      {
        assertion = all (n: config.age.secrets ? "common/k8s-pki/${n}.crt" && config.age.secrets ? "common/k8s-pki/${n}.key") caNames;
        message = "k8s-pki: CA declared in specs.nix has no matching age.secret under common/k8s-pki/";
      }
      {
        assertion = all (n: config.age.secrets ? "homelab-k8s/${n}.crt" && config.age.secrets ? "homelab-k8s/${n}.key") hostLeafNames;
        message = "k8s-pki: leaf declared in specs.nix has no matching age.secret under homelab-k8s/";
      }
    ];
  };
}
