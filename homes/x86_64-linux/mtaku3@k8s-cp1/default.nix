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
        };
        tmux = enabled;
        kube-cli = {
          enable = true;
          masterAddress = "https://192.168.11.102:6443";
        };
      };
    };

    agenix = {
      enable = true;
      userPubkeys = [
        "age18jn6pdtsy47aqmxnl32qc5w3jlfc2865ufjhdke2s4syc23g6fvsq9rsv7"
      ];
    };
  };

  home.stateVersion = "25.05";
}
