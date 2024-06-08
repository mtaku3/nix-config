{pkgs, ...}: {
  home.packages = [pkgs.direnv];

  programs.zsh.initExtra = ''
    eval "$(direnv hook zsh)"
  '';
}
