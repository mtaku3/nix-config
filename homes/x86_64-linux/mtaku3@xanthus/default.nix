{lib, ...}:
with lib;
with lib.capybara; {
  home.keyboard = {
    model = "pc104";
    layout = "jp,us";
    variant = ",dvorak";
  };

  capybara = {
    xserver.windowManager.xmonad = enabled;
    app = {
      desktop = {
        slack = enabled;
        discord = enabled;
        gimp = enabled;
        obsidian = enabled;
        libreoffice = enabled;
        remmina = enabled;
        rdp-acri = enabled;
        zathura = enabled;
        zoom-us = enabled;
        arandr = enabled;
        xplugd = enabled;
      };
      dev = {
        kube-cli = enabled;
        pycharm = enabled;
        zsh = {
          enable = true;
        };
        neovim = enabled;
        git = {
          enable = true;
          username = "mtaku3";
          email = "me@mtaku3.com";
          signingKey = "4DB490B409F22369";
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
