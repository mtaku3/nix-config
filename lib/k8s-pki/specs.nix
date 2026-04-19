# Static definition of the homelab Kubernetes PKI.
# Pure data: consumed by packages/k8s-pki (generator) and modules/nixos/app/server/kubernetes/mypki.nix.
# String tokens {host.name}, {host.advertiseIP}, {host.masterAddress} are substituted at generation time.
{
  cas = {
    "ca" = {
      CN = "kubernetes-ca";
      expiry = "87600h";
    };
    "etcd/ca" = {
      CN = "etcd-ca";
      expiry = "87600h";
    };
    "front-proxy-ca" = {
      CN = "kubernetes-front-proxy-ca";
      expiry = "87600h";
    };
  };

  sa = {
    algo = "rsa";
    keyBits = 2048;
  };

  # scope: "master" | "all"
  leaves = {
    "apiserver" = {
      signer = "ca";
      CN = "kube-apiserver";
      hosts = [
        "kubernetes"
        "kubernetes.default"
        "kubernetes.default.svc"
        "kubernetes.default.svc.cluster.local"
        "127.0.0.1"
        "10.0.0.1"
        "{host.advertiseIP}"
        "{host.masterAddress}"
      ];
      profile = "server";
      expiry = "8760h";
      scope = "master";
    };
    "apiserver-etcd-client" = {
      signer = "etcd/ca";
      CN = "kube-apiserver-etcd-client";
      O = "system:masters";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
    "apiserver-kubelet-client" = {
      signer = "ca";
      CN = "kube-apiserver-kubelet-client";
      O = "system:masters";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
    "front-proxy-client" = {
      signer = "front-proxy-ca";
      CN = "front-proxy-client";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
    "controller-manager" = {
      signer = "ca";
      CN = "system:kube-controller-manager";
      hosts = ["127.0.0.1" "{host.advertiseIP}"];
      profile = "server";
      expiry = "8760h";
      scope = "master";
    };
    "controller-manager-client" = {
      signer = "ca";
      CN = "system:kube-controller-manager";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
    "scheduler" = {
      signer = "ca";
      CN = "system:kube-scheduler";
      hosts = ["127.0.0.1" "{host.advertiseIP}"];
      profile = "server";
      expiry = "8760h";
      scope = "master";
    };
    "scheduler-client" = {
      signer = "ca";
      CN = "system:kube-scheduler";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
    "addon-manager-client" = {
      signer = "ca";
      CN = "system:kube-addon-manager";
      O = "system:masters";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
    "cluster-admin-client" = {
      signer = "ca";
      CN = "kubernetes-admin";
      O = "system:masters";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
    "kubelet" = {
      signer = "ca";
      CN = "system:node:{host.name}";
      O = "system:nodes";
      hosts = ["{host.name}" "{host.advertiseIP}"];
      profile = "server";
      expiry = "8760h";
      scope = "all";
    };
    "kubelet-client" = {
      signer = "ca";
      CN = "system:node:{host.name}";
      O = "system:nodes";
      profile = "client";
      expiry = "8760h";
      scope = "all";
    };
    "kube-proxy-client" = {
      signer = "ca";
      CN = "system:kube-proxy";
      profile = "client";
      expiry = "8760h";
      scope = "all";
    };
    "flannel-client" = {
      signer = "ca";
      CN = "flannel-client";
      profile = "client";
      expiry = "8760h";
      scope = "all";
    };
    "flannel-etcd-client" = {
      signer = "etcd/ca";
      CN = "flannel-etcd-client";
      profile = "client";
      expiry = "8760h";
      scope = "all";
    };
    "etcd/server" = {
      signer = "etcd/ca";
      CN = "etcd-server";
      hosts = ["127.0.0.1" "{host.advertiseIP}" "{host.name}"];
      profile = "server-etcd";
      expiry = "8760h";
      scope = "master";
    };
    "etcd/peer" = {
      signer = "etcd/ca";
      CN = "etcd-peer";
      hosts = ["127.0.0.1" "{host.advertiseIP}" "{host.name}"];
      profile = "peer-etcd";
      expiry = "8760h";
      scope = "master";
    };
    "etcd/healthcheck-client" = {
      signer = "etcd/ca";
      CN = "etcd-healthcheck-client";
      profile = "client";
      expiry = "8760h";
      scope = "master";
    };
  };

  users = {
    "cluster-admin" = {
      signer = "ca";
      CN = "kubernetes-admin";
      O = "system:masters";
      profile = "client";
      expiry = "8760h";
    };
  };

  profiles = {
    server = {usages = ["signing" "key encipherment" "server auth"];};
    client = {usages = ["signing" "key encipherment" "client auth"];};
    server-etcd = {usages = ["signing" "key encipherment" "server auth" "client auth"];};
    peer-etcd = {usages = ["signing" "key encipherment" "server auth" "client auth"];};
  };
}
