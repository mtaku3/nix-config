{
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.capybara; let
  system = pkgs.system;
  nixvim' = inputs.nixvim.legacyPackages.${system};
  nixvim-module = {
    inherit system;
    module = import ./config;
  };
  nvim = nixvim'.makeNixvimWithModule nixvim-module;
in
  nvim
