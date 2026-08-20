# Exposes pkgs.openclaw and pkgs.openclawPackages, which the programs.openclaw
# home-manager module resolves its default package from.
{inputs, ...}: inputs.nix-openclaw.overlays.default
