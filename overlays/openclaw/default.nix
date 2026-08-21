# Exposes pkgs.openclaw and pkgs.openclawPackages, which the programs.openclaw
# home-manager module resolves its default package from.
#
# Built from nix-openclaw's own nixpkgs rather than ours. Its toolchain tracks
# the pin it develops against (nixos-unstable), and openclaw hard-fails at
# startup on an older Node than it declares -- nixos-25.11 ships nodejs_22
# 22.22.2 against a >=22.22.3 requirement. Since openclaw's wrapper prepends its
# own toolchain, that version is the one that counts, so it has to come from a
# channel new enough to satisfy it.
{inputs, ...}: final: prev: let
  openclawPkgs = import inputs.nix-openclaw.inputs.nixpkgs {
    inherit (prev.stdenv.hostPlatform) system;
    overlays = [inputs.nix-openclaw.overlays.default];
    inherit (prev) config;
  };
in {
  inherit (openclawPkgs) openclaw openclawPackages openclawRuntimePlugins;
}
