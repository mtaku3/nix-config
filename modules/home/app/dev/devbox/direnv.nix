{
  lib,
  pkgs,
  ...
}: {
  programs.direnv =
    {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      # The fish test phase OOMs on darwin; skip tests there to keep the build
      # from getting killed.
      package = pkgs.direnv.overrideAttrs (_: {doCheck = false;});
    };

  capybara.impermanence.directories = [
    ".local/share/direnv"
  ];
}
