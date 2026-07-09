{lib, ...}:
with lib;
with lib.capybara; {
  capybara = {
    app = {
      desktop = {
        kitty = enabled;
      };
      dev = {
        zsh = enabled;
        neovim = enabled;
        git = {
          enable = true;
          username = "mtaku3";
          email = "me@mtaku3.com";
          signingKey = "EA7E68BE661AE1D8";
          signByDefault = true;
        };
        gpg = enabled;
        gh = enabled;
        tmux = enabled;
        devbox = enabled;
        claude-code = enabled;
      };
    };
  };

  home.stateVersion = "24.11";
}
