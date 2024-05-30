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
  ];

  scripts.fmt.exec = "nix fmt && ormolu --mode inplace $(find . -name '*.hs')";
}
