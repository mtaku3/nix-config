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
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [kubectl kubeseal kubernetes-helm kustomize pkgs.capybara.kubecerts];

    home.file.".kube/config".text = builtins.toJSON {
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
    };

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
