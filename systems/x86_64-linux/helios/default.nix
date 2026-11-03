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
    # NetBird pushes per-domain DNS to resolved; resolvconf mode fails under the hardened daemon.
    system.network.resolved = true;

    app.server = {
      ssh = enabled;
      fail2ban = enabled;
      netbird = enabled;
      openbot = {
        enable = true;
        packages = with pkgs; [
          git
          # npx, for MCP servers such as esa's (@esaio/esa-mcp-server). OpenBot
          # gives an MCP server only the environment set in its MCP settings,
          # so tokens such as esa's go there.
          nodejs
          # gog with its file keyring, as the gogcli home module sets it up.
          # Also for `sudo -u openbot gog auth ...`, which sets up its account.
          (writeShellScriptBin "gog" ''
            export GOG_KEYRING_BACKEND=''${GOG_KEYRING_BACKEND:-file}
            if [ -z "''${GOG_KEYRING_PASSWORD-}" ] && [ -r ${config.age.secrets."openbot/gog-keyring-password".path} ]; then
              GOG_KEYRING_PASSWORD="$(cat ${config.age.secrets."openbot/gog-keyring-password".path})"
              export GOG_KEYRING_PASSWORD
            fi
            exec ${getExe pkgs.capybara.gogcli} "$@"
          '')
        ];
        # Claude through CLIProxyAPI, with a key of the bot's own.
        environment.ANTHROPIC_BASE_URL = "https://api.cliproxy.mtaku3.com";
        environmentFiles = [
          config.age.secrets."openbot/cliproxy-env".path # ANTHROPIC_AUTH_TOKEN
        ];
      };
      openmausbot = {
        enable = true;
        packages = with pkgs; [
          # gog with its file keyring, as the gogcli home module sets it up.
          # Also for `sudo -iu openmausbot gog auth ...`, which sets up its
          # account.
          (writeShellScriptBin "gog" ''
            export GOG_KEYRING_BACKEND=''${GOG_KEYRING_BACKEND:-file}
            if [ -z "''${GOG_KEYRING_PASSWORD-}" ] && [ -r ${config.age.secrets."openmausbot/gog-keyring-password".path} ]; then
              GOG_KEYRING_PASSWORD="$(cat ${config.age.secrets."openmausbot/gog-keyring-password".path})"
              export GOG_KEYRING_PASSWORD
            fi
            exec ${getExe pkgs.capybara.gogcli} "$@"
          '')
        ];
        # Every Claude bot through CLIProxyAPI, with a key of the bot's own.
        environment.OMB_ANTHROPIC_API_URL = "https://api.cliproxy.mtaku3.com";
        environmentFiles = [
          config.age.secrets."openmausbot/cliproxy-env".path # OMB_ANTHROPIC_API_KEY
        ];
      };
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

  nix.settings.trusted-users = ["mtaku3"];

  # Warpgate on edge1 logs in as mtaku3 on behalf of SSO-authenticated users.
  users.users.mtaku3.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBznGw/YMlO4fQVApPr86pcaednatPJ+r+eDT4JRC6Ho warpgate@edge1"
  ];

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
  # Read by the gog wrapper of the OpenBot server, as its user.
  age.secrets."openbot/gog-keyring-password" = {
    mode = "400";
    owner = "openbot";
    group = "openbot";
  };
  # Read by the gog wrapper of the OpenMausBot server, as its user.
  age.secrets."openmausbot/gog-keyring-password" = {
    mode = "400";
    owner = "openmausbot";
    group = "openmausbot";
  };
  age.secrets."sshfs/id_ed25519_t4" = {
    mode = "400";
    owner = "mtaku3";
    group = "users";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/sshfs 0700 root root -"
  ];
  services.envfs = {
    enable = true;
    extraFallbackPathCommands = ''
      ln -s ${pkgs.bash}/bin/bash $out/bash
      ln -s ${pkgs.which}/bin/which $out/which
      ln -s ${pkgs.coreutils}/bin/true $out/true
    '';
  };
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
  fileSystems."/mnt/miubiq-exp-data" = {
    device = "matsushita@fs.miubiq.cs.titech.ac.jp:/mnt/exp-nfs-data";
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
