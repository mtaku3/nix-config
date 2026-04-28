{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    package = pkgs.direnv.overrideAttrs (_: {doCheck = false;});
  };

  capybara.impermanence.directories = [
    ".local/share/direnv"
  ];
}
