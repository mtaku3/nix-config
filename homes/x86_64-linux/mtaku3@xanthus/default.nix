{lib, ...}:
with lib;
with lib.capybara; {
  home.keyboard = {
    model = "pc104";
    layout = "jp,us";
    variant = ",dvorak";
  };

  capybara = {
    xserver = {
      windowManager.xmonad = enabled;
      xrdp = {
        enable = true;
        session = "xmonad";
      };
    };
    wayland.windowManager.hyprland = enabled;
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
        claude-code = enabled;
        minio-cli = enabled;
        # kube-cli = {
        #   enable = true;
        #   masterAddress = "https://192.168.10.2:6443";
        # };
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

    agenix = enabled;
  };

  home.stateVersion = "24.05";
}
