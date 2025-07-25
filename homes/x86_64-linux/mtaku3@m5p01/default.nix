{lib, ...}:
with lib;
with lib.capybara; {
  capybara = {
    openssh.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF3/1HWL3C9D7+w4Et1zrGdJVTX27ibiRsITpe9rUCUw mtaku3@xanthus"
    ];

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
        kube-cli = enabled;
      };
    };

    impermanence = {
      enable = true;
      name = "/persist/home/mtaku3";
      directories = [
        "Downloads"
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

  home.stateVersion = "25.05";
}
