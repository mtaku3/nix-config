{
  lib,
  pkgs,
  inputs,
  system,
  ...
}: let
  # data.nix expects user-lib entries at lib top-level (e.g. lib.k8s-pki),
  # but snowfall namespaces user-lib under lib.capybara.*. Merge it back up.
  dataLib = lib // (lib.capybara or {});
  data = import ./data.nix {
    inherit (inputs) self;
    inherit system;
    lib = dataLib;
  };
  dataJson = pkgs.writeText "k8s-pki-data.json" (builtins.toJSON data);

  libSh = ./scripts/lib.sh;
  cmdBootstrap = ./scripts/cmd-bootstrap.sh;
  cmdRenew = ./scripts/cmd-renew.sh;
  cmdRotateCa = ./scripts/cmd-rotate-ca.sh;
  cmdStatus = ./scripts/cmd-status.sh;

  mkCmd = name: script:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [cfssl age openssl jq git coreutils gnused gawk];
      text = ''
        export K8S_PKI_DATA=${dataJson}
        export K8S_PKI_LIB=${libSh}
        export K8S_PKI_BOOTSTRAP=${cmdBootstrap}
        ${builtins.readFile script}
      '';
    };

  bootstrap = mkCmd "k8s-pki-bootstrap" cmdBootstrap;
  renew = mkCmd "k8s-pki-renew" cmdRenew;
  rotate-ca = mkCmd "k8s-pki-rotate-ca" cmdRotateCa;
  status = mkCmd "k8s-pki-status" cmdStatus;
in
  pkgs.symlinkJoin {
    name = "k8s-pki";
    paths = [bootstrap renew rotate-ca status];
    passthru = {
      inherit bootstrap renew rotate-ca status;
    };
    meta = {
      description = "k8s-pki subcommand scripts (bootstrap, renew, rotate-ca, status)";
      platforms = lib.platforms.unix;
      mainProgram = "k8s-pki-status";
    };
  }
