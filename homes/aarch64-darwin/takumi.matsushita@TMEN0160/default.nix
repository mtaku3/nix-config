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
        herdr = enabled;
      };
    };
  };

  # Load Homebrew-installed nvm (macOS-only path, hence host-scoped).
  programs.zsh.initContent = mkAfter ''
    export NVM_DIR="$HOME/.nvm"
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
  '';

  home.stateVersion = "24.11";
}
