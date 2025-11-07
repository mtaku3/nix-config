{
  lib,
  pkgs,
  inputs,
  system,
  ...
}:
with lib;
with lib.capybara;
  inputs.kubecerts.packages.${system}.kubecerts
