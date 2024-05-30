{
  lib,
  inputs,
  ...
}:
with lib;
with lib.capybara; {
  imports = with inputs; [
    impermanence.nixosModules.home-manager.impermanence
  ];

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
      };
      dev = {
        zsh = {
          enable = true;
          oh-my-zsh.plugins = [];
        };
        neovim = enabled;
        git = {
          enable = true;
          username = "mtaku3";
          email = "m.taku3.1222@gmail.com";
          signingKey = "CE36E3A2959377DA";
          signByDefault = true;
        };
        gh = enabled;
        tmux = enabled;
        gpg = enabled;
        devenv = enabled;
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
      ];
      allowOther = true;
    };
  };

  home.stateVersion = "23.11";
}
