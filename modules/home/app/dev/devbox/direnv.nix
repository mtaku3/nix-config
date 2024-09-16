{pkgs, ...}: {
  home.packages = [pkgs.direnv];

  programs.zsh.initExtra = ''
    eval "$(direnv hook zsh)"
  '';

  capybara.app.dev.zsh.oh-my-zsh.plugins = ["direnv"];

  capybara.impermanence.directories = [
    ".local/share/direnv"
  ];
}
