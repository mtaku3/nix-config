{pkgs, ...}: {
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  capybara.impermanence.directories = [
    ".local/share/direnv"
  ];
}
