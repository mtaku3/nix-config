{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.kube-cli;
  secret = name: config.age.secrets."homelab-k8s/${name}".path;
in {
  options.capybara.app.dev.kube-cli = {
    enable = mkBoolOpt false "Whether to enable the kube-cli";
    masterAddress = mkOpt types.str "" "Endpoint url for the kubernetes master";
    clusterProxy = mkOpt (types.nullOr types.str) null "FQDN of a NetBird ClusterProxy; when set, kubectl goes through it as this NetBird peer instead of to masterAddress with the cluster-admin certificate";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [kubectl kubeseal kubernetes-helm kustomize pkgs.capybara.k8s-pki.status];

    home.file.".kube/config".text = builtins.toJSON (
      if cfg.clusterProxy != null
      then {
        # What `netbird kubernetes write-kubeconfig` writes: the proxy
        # authenticates the caller by its NetBird peer, and the connection is
        # already encrypted by WireGuard, so there is no credential or CA here.
        apiVersion = "v1";
        kind = "Config";
        clusters = [
          {
            name = "homelab";
            cluster = {
              server = "https://${cfg.clusterProxy}";
              insecure-skip-tls-verify = true;
            };
          }
        ];
        users = [
          {
            name = "netbird";
            user.token = "none";
          }
        ];
        contexts = [
          {
            name = "homelab";
            context = {
              cluster = "homelab";
              user = "netbird";
            };
          }
        ];
        current-context = "homelab";
      }
      else {
        apiVersion = "v1";
        kind = "Config";
        clusters = [
          {
            name = "homelab";
            cluster = {
              certificate-authority = secret "ca.crt";
              server = cfg.masterAddress;
            };
          }
        ];
        users = [
          {
            name = "cluster-admin";
            user = {
              client-certificate = secret "cluster-admin.crt";
              client-key = secret "cluster-admin.key";
            };
          }
        ];
        contexts = [
          {
            name = "homelab";
            context = {
              cluster = "homelab";
              user = "cluster-admin";
            };
          }
        ];
        current-context = "homelab";
      }
    );

    capybara.impermanence.directories = [
      ".kube"
    ];

    programs.zsh.shellAliases = {
      k = "kubectl";
      ks = "kubeseal";
      kh = "helm";
      kx = "kustomize";
    };
  };
}
