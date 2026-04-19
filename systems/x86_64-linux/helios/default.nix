{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.capybara; {
  imports = [
    ./hardware-configuration.nix
  ];

  capybara = {
    suites.common = enabled;

    app.server = {
      ssh = enabled;
      fail2ban = enabled;
      netbird = enabled;
    };

    app.dev = {
      docker = enabled;
      nix-ld.enable = true;
    };

    agenix = {
      enable = true;
      hostPubkeys = [
        "age12qlevvrnac626xs3ztamhtfyr6r48g40v7u738hwnyf323t76ygs6mqhjx"
      ];
    };
    impermanence = {
      enable = true;
      name = "/persist";
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/sshfs"
      ];
    };
  };

  services.journald.storage = "persistent";

  nix.settings.trusted-users = ["mtaku3"];

  users.users.root.packages = with pkgs; [git vim curl wget];

  # sshfs mount for miubiq lab filesystem (fs.miubiq.cs.titech.ac.jp:/records)
  programs.fuse.userAllowOther = true;
  system.fsPackages = [pkgs.sshfs];
  age.secrets."sshfs/id_rsa_miubiq_fs" = {
    mode = "400";
    owner = "mtaku3";
    group = "users";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/sshfs 0700 root root -"
  ];
  fileSystems."/mnt/miubiq-fs" = {
    device = "matsushita@fs.miubiq.cs.titech.ac.jp:/records";
    fsType = "fuse.sshfs";
    options = [
      "allow_other"
      "uid=1000"
      "gid=100"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=30"
      "reconnect"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      "port=24322"
      "IdentityFile=${config.age.secrets."sshfs/id_rsa_miubiq_fs".path}"
      "UserKnownHostsFile=/var/lib/sshfs/known_hosts"
      "StrictHostKeyChecking=accept-new"
      "sftp_server=/usr/lib/openssh/sftp-server\\040-u0"
    ];
  };

  system.stateVersion = "25.05";
}
