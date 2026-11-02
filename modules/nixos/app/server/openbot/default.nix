{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.openbot;
  inherit (cfg) user;

  # OpenBot's self-hosted server, as its own installer sets it up on Ubuntu
  # (docs/self-hosted-server.md): the release in /opt/OpenBot, owned by root,
  # and openbot.service running it as a user of its own, whose home holds the
  # app data and the agents' workspaces. The release is not pinned: the
  # official scripts install it and keep it updated, and the app's Server
  # settings > Updates works.
  #
  # The user is OpenBot's alone because no Permissions level of an agent --
  # Full access (the default), Ask first, or Workspace only -- limits what it
  # reads or where it connects: the agents can read every file of the user
  # they run as. Give them credentials of their own, scoped to what they need.
  #
  # The scripts (scripts/hosting/ upstream) run unmodified from /opt/OpenBot/
  # hosted, which every update replaces. NixOS only provides what they expect
  # of Ubuntu:
  #
  # - The units. Upstream installs them into /etc/systemd/system, which is
  #   read-only here, so they are declared below with the upstream contents.
  #   OpenBot itself uses the root-run updater only when
  #   /etc/systemd/system/openbot-update-request.path exists.
  # - The packages of packages.txt. The libraries are given to nix-ld and the
  #   commands to the units' PATH, so the apt step is told they are installed.
  #
  # The scripts still write the units and the AppArmor profile of each release
  # (install_hosting). The units that run them get a private, empty tmpfs on
  # those two directories, so the writes succeed and go nowhere. Units that a
  # new release changes therefore do not follow it: compare them with
  # scripts/hosting/*.service on an update that changes them.
  install = "/opt/OpenBot";
  hosted = "${install}/hosted";

  # apt and dpkg stand-ins for the install and update scripts. install-server.sh
  # only checks that apt-get exists, and install_packages installs a package
  # that dpkg-query does not report as installed.
  aptShims = pkgs.symlinkJoin {
    name = "openbot-apt-shims";
    paths = [
      (pkgs.writeShellScriptBin "dpkg-query" ''
        # Nix provides the packages of packages.txt (see the openbot module).
        echo installed
      '')
      (pkgs.writeShellScriptBin "apt-get" ''
        echo "apt-get: NixOS has no apt; the openbot module provides the packages." >&2
        exit 1
      '')
    ];
  };

  scriptPath = with pkgs; [
    bash
    coreutils
    curl
    diffutils
    findutils
    gawk
    gnugrep
    gnused
    openssl
    procps
    util-linux
  ];

  # What packages.txt installs for the server: D-Bus, the keyring, the virtual
  # displays, and bubblewrap for the Codex sandbox. The agents' shell commands
  # see the same PATH, so the user's profile (cfg.packages) follows.
  serverPath =
    scriptPath
    ++ (with pkgs; [
      bubblewrap
      dbus
      gnome-keyring
      xauth
      xdpyinfo
      xvfb-run
      # Not in packages.txt: the Claude sandbox, which an agent's Workspace
      # only level needs, runs bubblewrap and socat.
      socat
    ])
    ++ [
      "/run/wrappers"
      "/etc/profiles/per-user/${user}"
      "/run/current-system/sw"
    ];

  # The units that install or update the release. See above for the tmpfs.
  # SYSTEMCTL_INSTALL_CLIENT_SIDE makes `systemctl enable` write its links in
  # that tmpfs too, instead of asking PID 1 to write them in the real one.
  updater = {
    path = [aptShims] ++ scriptPath;
    environment.SYSTEMCTL_INSTALL_CLIENT_SIDE = "1";
    serviceConfig.TemporaryFileSystem = [
      "/etc/systemd/system"
      "/etc/apparmor.d"
    ];
  };
in {
  options.capybara.app.server.openbot = with types; {
    enable = mkBoolOpt false "Whether to run an OpenBot self-hosted server";

    user = mkOpt str "openbot" ''
      The user that runs OpenBot and its agents, made for it with its home in
      /var/lib/<user>. The installer keeps the user of an existing install:
      changing it needs a new install.
    '';

    packages = mkOpt (listOf package) (with pkgs; [git]) ''
      Commands the agents can run, besides those of the system.
    '';

    environment = mkOpt (attrsOf str) {} ''
      Environment of OpenBot, which the agents and provider CLIs inherit, e.g.
      `ANTHROPIC_BASE_URL` for an LLM gateway.
    '';

    environmentFiles = mkOpt (listOf str) [] ''
      Files of `KEY=value` lines added to the environment, for secrets such as
      the gateway's `ANTHROPIC_AUTH_TOKEN`; typically agenix secrets. The
      agents can read these values too.
    '';
  };

  config = mkIf cfg.enable {
    # As openbot-server-setup would make it: a login shell for the agents'
    # commands, and no password.
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = "/var/lib/${user}";
      createHome = true;
      shell = pkgs.bashInteractive;
      inherit (cfg) packages;
    };
    users.groups.${user} = {};

    # The libraries of packages.txt: Electron's, with libsecret, which it
    # loads for the keyring, and those of the remote desktop runtime.
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        alsa-lib
        at-spi2-core
        cairo
        cups
        dbus
        expat
        glib
        gtk3
        libgbm
        libsecret
        libxkbcommon
        libxscrnsaver
        nspr
        nss
        pango
        systemd # libudev
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
        # The remote desktop runtime (Sunshine).
        curl
        libcap
        libevdev
        libpulseaudio
        libva
        libxtst
        numactl
        openssl
      ];
    };

    # The upstream command, which the release keeps at ${hosted}/openbot. It
    # talks to OpenBot with curl.
    environment.systemPackages = [
      pkgs.curl
      (pkgs.runCommand "openbot-command" {} ''
        mkdir -p $out/bin
        ln -s ${hosted}/openbot $out/bin/openbot
      '')
    ];

    systemd.tmpfiles.rules = [
      # install_hosting links the command here, and the mount point of the
      # tmpfs over the AppArmor profiles must exist.
      "d /usr/local/bin 0755 root root -"
      "d /etc/apparmor.d 0755 root root -"
    ];

    # The first install, with the official installer. It starts openbot.service
    # and the update timer when it is done.
    systemd.services.openbot-install = recursiveUpdate updater {
      description = "Install OpenBot as a self-hosted server";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      unitConfig.ConditionPathExists = "!${hosted}/mode";
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "30min";
      };
      script = ''
        set -o pipefail
        curl -fsSL https://raw.githubusercontent.com/nightly-labs/openbot/main/scripts/install-server.sh |
          bash -s -- --user ${user}
      '';
    };

    # scripts/hosting/openbot.service
    systemd.services.openbot = {
      description = "OpenBot hosted server";
      wants = ["network-online.target" "openbot-update-apply.service"];
      after = ["network-online.target" "display-manager.service"];
      wantedBy = ["multi-user.target"];
      path = serverPath;
      environment = cfg.environment // {XDG_RUNTIME_DIR = "/run/openbot";};
      unitConfig.ConditionPathExists = [
        "!/run/openbot-pre-stop"
        # Not installed yet: openbot-install.service starts it.
        "${hosted}/openbot-hosted-server"
      ];
      serviceConfig = {
        Type = "simple";
        User = user;
        RuntimeDirectory = "openbot";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = "-+${hosted}/openbot-hosted-update trigger";
        ExecStart = "${hosted}/openbot-hosted-server";
        ExecStop = "${hosted}/openbot-hosted-server --stop";
        Restart = "always";
        RestartSec = 10;
        TimeoutStopSec = 60;
        MemoryMax = "90%";
        OOMScoreAdjust = -500;
        OOMPolicy = "continue";
        EnvironmentFile = cfg.environmentFiles;

        # Not upstream: what the agents can read beyond the user's own files.
        # The other users' homes, the network filesystems that are mounted
        # with allow_other under /mnt (hidden before automount triggers them),
        # and the other users' processes. The network stays open.
        ProtectHome = true;
        TemporaryFileSystem = "/mnt:ro";
        ProtectProc = "invisible";
      };
    };

    # scripts/hosting/openbot-update.service
    systemd.services.openbot-update = recursiveUpdate updater {
      description = "Stage an OpenBot update";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${hosted}/openbot-hosted-update stage";
        Nice = 19;
        IOSchedulingClass = "idle";
        CPUWeight = "idle";
        TimeoutStartSec = "30min";
      };
    };

    # scripts/hosting/openbot-update.timer
    systemd.timers.openbot-update = {
      description = "Check for an OpenBot update";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnActiveSec = "5min";
        OnUnitActiveSec = "6h";
        RandomizedDelaySec = "5min";
      };
    };

    # scripts/hosting/openbot-update-apply.service
    systemd.services.openbot-update-apply = recursiveUpdate updater {
      description = "Apply a staged OpenBot update";
      before = ["openbot.service"];
      wantedBy = ["multi-user.target"];
      unitConfig.ConditionPathExists = "${hosted}/openbot-hosted-update";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${hosted}/openbot-hosted-update boot";
        TimeoutStartSec = "15min";
      };
    };

    # scripts/hosting/openbot-update-request.path
    systemd.paths.openbot-update-request = {
      description = "Watch for an OpenBot update request";
      wantedBy = ["paths.target"];
      pathConfig.PathExists = [
        "/run/openbot/update-stage"
        "/run/openbot/update-install"
      ];
    };

    # scripts/hosting/openbot-update-request.service
    systemd.services.openbot-update-request = recursiveUpdate updater {
      description = "Update OpenBot on request";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${hosted}/openbot-hosted-update request";
        TimeoutStartSec = "45min";
      };
    };

    # The release; the home with the app data and the workspaces; and the
    # keyring with the key of the encrypted app data, which goes with it.
    capybara.impermanence.directories = [
      install
      {
        directory = "/var/lib/${user}";
        inherit user;
        group = user;
        mode = "0700";
      }
      {
        directory = "/srv/openbot-hosted";
        inherit user;
        group = user;
        mode = "0700";
      }
    ];
  };
}
