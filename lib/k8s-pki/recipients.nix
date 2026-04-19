# Pure recipient-policy function for the homelab k8s PKI.
#
# Input:
#   hosts :: { <name> = { name; role; advertiseIP; masterAddress; hostPubkeys; }; ... }
#   users :: { <name@host> = { name; host; userPubkeys; }; ... }
#
# Output:
#   { <key> = [ "age1..." | "ssh-ed25519 ..." ... ]; ... }
# Keys for shared CAs use agenix-style relative paths ("common/k8s-pki/...").
# Keys for per-host leaves and per-user certs use full repo-relative paths ("secrets/<host>/...").
# The runtime shell branches on key prefix ("common/" vs "secrets/") to determine ciphertext location.
{lib}: {
  hosts,
  users,
}: let
  inherit (lib) flatten concatMap attrValues filterAttrs unique concatMapAttrs;

  allHostPubkeys = flatten (concatMap (h: h.hostPubkeys) (attrValues hosts));
  masterPubkeys =
    flatten (concatMap (h: h.hostPubkeys)
      (attrValues (filterAttrs (_: h: h.role == "master") hosts)));
  allUserPubkeys = flatten (concatMap (u: u.userPubkeys) (attrValues users));

  publicRecipients = unique (allHostPubkeys ++ allUserPubkeys);
  privateRecipients = unique (masterPubkeys ++ allUserPubkeys);

  commonPublicPaths = [
    "common/k8s-pki/ca.crt"
    "common/k8s-pki/etcd/ca.crt"
    "common/k8s-pki/front-proxy-ca.crt"
    "common/k8s-pki/sa.pub"
  ];

  commonPrivatePaths = [
    "common/k8s-pki/ca.key"
    "common/k8s-pki/etcd/ca.key"
    "common/k8s-pki/front-proxy-ca.key"
    "common/k8s-pki/sa.key"
  ];

  common =
    builtins.listToAttrs (map (p: {
        name = p;
        value = publicRecipients;
      })
      commonPublicPaths)
    // builtins.listToAttrs (map (p: {
        name = p;
        value = privateRecipients;
      })
      commonPrivatePaths);

  hostLeafFiles = [
    "apiserver.crt"
    "apiserver.key"
    "apiserver-etcd-client.crt"
    "apiserver-etcd-client.key"
    "apiserver-kubelet-client.crt"
    "apiserver-kubelet-client.key"
    "front-proxy-client.crt"
    "front-proxy-client.key"
    "controller-manager.crt"
    "controller-manager.key"
    "controller-manager-client.crt"
    "controller-manager-client.key"
    "scheduler.crt"
    "scheduler.key"
    "scheduler-client.crt"
    "scheduler-client.key"
    "addon-manager-client.crt"
    "addon-manager-client.key"
    "cluster-admin-client.crt"
    "cluster-admin-client.key"
    "kubelet.crt"
    "kubelet.key"
    "kubelet-client.crt"
    "kubelet-client.key"
    "kube-proxy-client.crt"
    "kube-proxy-client.key"
    "flannel-client.crt"
    "flannel-client.key"
    "flannel-etcd-client.crt"
    "flannel-etcd-client.key"
    "etcd/server.crt"
    "etcd/server.key"
    "etcd/peer.crt"
    "etcd/peer.key"
    "etcd/healthcheck-client.crt"
    "etcd/healthcheck-client.key"
  ];

  perHost =
    concatMapAttrs (
      hostName: h: let
        hostRecipients = unique (h.hostPubkeys ++ allUserPubkeys);
        prefix = "secrets/${hostName}/system/homelab-k8s";
      in
        builtins.listToAttrs (map (leaf: {
            name = "${prefix}/${leaf}";
            value = hostRecipients;
          })
          hostLeafFiles)
    )
    hosts;

  userCertFiles = ["ca.crt" "cluster-admin.crt" "cluster-admin.key"];

  perUser =
    concatMapAttrs (
      _: u: let
        prefix = "secrets/${u.host}/home/${u.name}/homelab-k8s";
      in
        builtins.listToAttrs (map (f: {
            name = "${prefix}/${f}";
            value = unique u.userPubkeys;
          })
          userCertFiles)
    )
    users;
in
  common // perHost // perUser
