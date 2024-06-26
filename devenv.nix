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
    alejandra
    stylua
    nixos-generators
    nil
    haskell-language-server
    ghc
    lua-language-server
  ];

  scripts.fmt.exec = "nix fmt && ormolu --mode inplace $(find . -name '*.hs')";
  scripts.cleanup.exec = "rm *.qcow2 || true";
  scripts.dev.exec = "cleanup && $(nix flake check \".?submodules=1#\" || true) && $(nixos-generate -f vm --flake \".?submodules=1#$1\" | tail -n 1)";
  scripts.switch.exec = "nixos-rebuild switch --flake \".?submodules=1#$1\"";
  scripts.check.exec = "nix flake check \".?submodules=1#\"";

  cachix.enable = false;
}
