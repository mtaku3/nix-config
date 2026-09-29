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
      docker = {
        enable = true;
        mode = "rootful";
        users = ["mtaku3"];
      };
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

  programs.nix-ld.libraries = with pkgs; [
    glib
    glibc
    openssl
    libffi
    bzip2
    xz
    ncurses
    readline
    sqlite
    expat
    libxml2
    libxslt
    libuuid
    libjpeg
    libpng
    libtiff
    libwebp
    freetype
    fontconfig
    cairo
    pango
    gdk-pixbuf
    gtk3
    dbus
    mesa
    libGL
    libglvnd
    xorg.libX11
    xorg.libXext
    xorg.libXrender
    xorg.libXi
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXtst
    xorg.libxcb
    xorg.libSM
    xorg.libICE
    nss
    nspr
    alsa-lib
    cups
    krb5
  ];

  services.journald.storage = "persistent";

  users.users.mtaku3.linger = true;

  services.nginx = {
    enable = true;
    virtualHosts.openscience = {
      listen = [
        {
          addr = "192.168.10.101";
          port = 4097;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:4096";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host localhost:4096;
          include ${config.age.secrets."openscience/nginx-auth.conf".path};
          proxy_buffering off;
          proxy_read_timeout 1h;
          proxy_send_timeout 1h;
          client_max_body_size 64m;
        '';
      };
    };
  };
  age.secrets."openscience/nginx-auth.conf" = {
    mode = "400";
    owner = config.services.nginx.user;
    group = config.services.nginx.group;
  };

  networking.firewall.extraCommands = ''
    iptables -I nixos-fw 1 -p tcp -s 192.168.10.102 --dport 4097 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -p tcp -s 192.168.10.102 --dport 4097 -j nixos-fw-accept || true
  '';

  nix.settings.trusted-users = ["mtaku3"];

  home-manager.backupFileExtension = "bak";

  users.users.root.packages = with pkgs; [git vim curl wget];

  # sshfs mount for miubiq lab filesystem (fs.miubiq.cs.titech.ac.jp:/records)
  programs.fuse.userAllowOther = true;
  system.fsPackages = [pkgs.sshfs];
  age.secrets."sshfs/id_rsa_miubiq_fs" = {
    mode = "400";
    owner = "mtaku3";
    group = "users";
  };
  age.secrets."sshfs/id_ed25519_t4" = {
    mode = "400";
    owner = "mtaku3";
    group = "users";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/sshfs 0700 root root -"
    "L+ /usr/bin/which - - - - ${pkgs.which}/bin/which"
    "L+ /usr/bin/true - - - - ${pkgs.coreutils}/bin/true"
  ];
  fileSystems."/mnt/miubiq-fs" = {
    device = "matsushita@fs.miubiq.cs.titech.ac.jp:/records";
    fsType = "fuse.sshfs";
    options = [
      "allow_other"
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
  fileSystems."/mnt/t4" = {
    device = "un02216@login.t4.gsic.titech.ac.jp:/gs/bs/tga-miubiq_data_common/matsushita-pilot-fs";
    fsType = "fuse.sshfs";
    options = [
      "allow_other"
      "_netdev"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=30"
      "reconnect"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      "IdentityFile=${config.age.secrets."sshfs/id_ed25519_t4".path}"
      "UserKnownHostsFile=/var/lib/sshfs/known_hosts"
      "StrictHostKeyChecking=accept-new"
    ];
  };

  system.stateVersion = "25.05";
}
