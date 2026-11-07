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
      };
    };

    agenix = {
      enable = true;
      userPubkeys = [
        "age17789lpdf06693rpm8hcvq05e5r22agdflerg47eahrp9lnhjkfmqpch9vf"
      ];
    };
  };

  home.stateVersion = "25.05";
}
