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
        fcitx5 = enabled;
      };
      dev = {
        neovim = enabled;
        git = {
          enable = true;
          username = "mtaku3";
          email = "m.taku3.1222@gmail.com";
          signingKey = "CE36E3A2959377DA";
          signByDefault = true;
        };
        tmux = enabled;
      };
    };
  };

  home.stateVersion = "23.11";
}
