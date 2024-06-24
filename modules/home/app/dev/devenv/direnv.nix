{pkgs, ...}: {
  home.packages = [pkgs.direnv];

  programs.zsh.initExtra = ''
    eval "$(direnv hook zsh)"
  '';

  capybara.impermanence.directories = [
    ".local/share/direnv"
  ];
}
