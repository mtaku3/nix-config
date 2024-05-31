{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  packages = with pkgs; [
    husky
    lint-staged
    ormolu
    nixos-generators
  ];

  scripts.fmt.exec = "nix fmt && ormolu --mode inplace $(find . -name '*.hs')";
  scripts.cleanup.exec = "rm *.qcow2 || true";
  scripts.dev.exec = "cleanup && nix flake check && $(nixos-generate -f vm --flake \".?submodules=1#$1\" | tail -n 1)";
  scripts.switch.exec = "nixos-rebuild switch --flake \".?submodules=1#$1\"";

  cachix.enable = false;
}
