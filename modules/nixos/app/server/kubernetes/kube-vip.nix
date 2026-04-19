{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.kubernetes.kube-vip;
  top = config.services.kubernetes;
  host = name: config.age.secrets."homelab-k8s/${name}".path;
  ca = name: config.age.secrets."common/k8s-pki/${name}".path;
  adminConfPath = "/var/lib/kube-vip/admin.conf";
in {
  options.capybara.app.server.kubernetes.kube-vip = with types; {
    enable = mkBoolOpt false "Whether to deploy kube-vip as a static pod on this node";
    interface = mkOpt str "" "Host network interface kube-vip binds the VIP to";
    address = mkOpt str "" "Virtual IP address kube-vip advertises";
    image = mkOpt str "ghcr.io/kube-vip/kube-vip:v1.1.2" "kube-vip container image";
  };

  config = mkIf cfg.enable {
    systemd.services.kube-vip-kubeconfig = {
      description = "Generate self-contained kubeconfig for kube-vip";
      wantedBy = ["kubernetes.target"];
      before = ["kubelet.service"];
      after = ["agenix.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      path = [pkgs.kubectl pkgs.coreutils];
      script = ''
        set -euo pipefail
        install -d -m 0700 "$(dirname ${adminConfPath})"
        export KUBECONFIG=${adminConfPath}
        rm -f "$KUBECONFIG"
        kubectl config set-cluster local \
          --server=${top.apiserverAddress} \
          --certificate-authority=${ca "ca.crt"} \
          --embed-certs=true
        kubectl config set-credentials cluster-admin \
          --client-certificate=${host "cluster-admin-client.crt"} \
          --client-key=${host "cluster-admin-client.key"} \
          --embed-certs=true
        kubectl config set-context local \
          --cluster=local --user=cluster-admin
        kubectl config use-context local
        chmod 0600 "$KUBECONFIG"
      '';
    };

    services.kubernetes.kubelet.manifests.kube-vip = {
      apiVersion = "v1";
      kind = "Pod";
      metadata = {
        name = "kube-vip";
        namespace = "kube-system";
      };
      spec = {
        hostNetwork = true;
        hostAliases = [
          {
            hostnames = ["kubernetes"];
            ip = "127.0.0.1";
          }
        ];
        containers = [
          {
            name = "kube-vip";
            image = cfg.image;
            imagePullPolicy = "IfNotPresent";
            args = ["manager"];
            securityContext.capabilities = {
              add = ["NET_ADMIN" "NET_RAW"];
              drop = ["ALL"];
            };
            resources = {};
            env = [
              {
                name = "vip_arp";
                value = "true";
              }
              {
                name = "port";
                value = "6443";
              }
              {
                name = "vip_nodename";
                valueFrom.fieldRef.fieldPath = "spec.nodeName";
              }
              {
                name = "vip_interface";
                value = cfg.interface;
              }
              {
                name = "vip_subnet";
                value = "32";
              }
              {
                name = "dns_mode";
                value = "first";
              }
              {
                name = "dhcp_mode";
                value = "ipv4";
              }
              {
                name = "cp_enable";
                value = "true";
              }
              {
                name = "cp_namespace";
                value = "kube-system";
              }
              {
                name = "svc_enable";
                value = "true";
              }
              {
                name = "svc_leasename";
                value = "plndr-svcs-lock";
              }
              {
                name = "vip_leaderelection";
                value = "true";
              }
              {
                name = "vip_leasename";
                value = "plndr-cp-lock";
              }
              {
                name = "vip_leaseduration";
                value = "15";
              }
              {
                name = "vip_renewdeadline";
                value = "10";
              }
              {
                name = "vip_retryperiod";
                value = "2";
              }
              {
                name = "address";
                value = cfg.address;
              }
              {
                name = "prometheus_server";
                value = ":2112";
              }
            ];
            volumeMounts = [
              {
                name = "kubeconfig";
                mountPath = "/etc/kubernetes/admin.conf";
                readOnly = true;
              }
            ];
          }
        ];
        volumes = [
          {
            name = "kubeconfig";
            hostPath = {
              path = adminConfPath;
              type = "File";
            };
          }
        ];
      };
    };
  };
}
