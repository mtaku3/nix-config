{lib, ...}:
with lib;
with lib.capybara; {
  home.keyboard = {
    model = "pc104";
    layout = "us";
  };

  capybara = {
    xserver.windowManager.xmonad = enabled;
    app = {
      desktop = {
        fcitx5.layout = "us";
        slack = enabled;
        discord = enabled;
        gimp = enabled;
        obsidian = enabled;
        libreoffice = enabled;
        remmina = enabled;
        zathura = enabled;
        zoom-us = enabled;
      };
      dev = {
        zsh = {
          enable = true;
        };
        neovim = enabled;
        git = {
          enable = true;
          username = "mtaku3";
          email = "me@mtaku3.com";
          signingKey = "C4FCBB74F537002F";
          signByDefault = true;
        };
        gh = enabled;
        tmux = enabled;
        gpg = enabled;
        devbox = enabled;
        termius = enabled;
      };
    };

    impermanence = {
      enable = true;
      name = "/persist/home/mtaku3";
      directories = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        ".gnupg"
        ".ssh"
        "Workspaces"
      ];
      files = [
        ".local/state/nvim/trust"
      ];
      allowOther = true;
    };
  };

  home.stateVersion = "24.05";
}
