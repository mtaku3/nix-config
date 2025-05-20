{lib, ...}:
with lib;
with lib.capybara; {
  capybara = {
    app = {
      dev = {
        zsh = {
          enable = true;
        };
        neovim = enabled;
        git = {
          enable = true;
          username = "mtaku3";
          email = "me@mtaku3.com";
          signByDefault = false;
        };
        gh = enabled;
        tmux = enabled;
        gpg = enabled;
      };
    };

    impermanence = {
      enable = true;
      name = "/persist/home/deploy";
      directories = [
        "Downloads"
        ".gnupg"
        ".ssh"
        "Workspaces"
        "Deployments"
      ];
      files = [
        ".local/state/nvim/trust"
      ];
      allowOther = true;
    };
  };

  home.stateVersion = "24.05";
}
