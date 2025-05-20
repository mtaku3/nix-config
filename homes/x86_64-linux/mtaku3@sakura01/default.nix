{lib, ...}:
with lib;
with lib.capybara; {
  capybara = {
    openssh.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID2xlA28TUGIyv7OKOxc6ohMKU0t42hvT1kg0EEDXaHg mtaku3@xanthus"
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
        "Deployments"
      ];
      files = [
        ".local/state/nvim/trust"
      ];
      allowOther = true;
    };
  };

  home.stateVersion = "24.05";
}
