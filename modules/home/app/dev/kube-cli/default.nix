{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.kube-cli;
in {
  options.capybara.app.dev.kube-cli = {
    enable = mkBoolOpt false "Whether to enable the kube-cli";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [kubectl kubeseal kubernetes-helm kustomize];

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
