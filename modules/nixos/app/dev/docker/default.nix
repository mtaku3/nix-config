{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.docker;
in {
  options.capybara.app.dev.docker = with types;
    {
      enable = mkBoolOpt false "Whether to enable the docker";

      mode = mkOption {
        type = enum ["rootless" "rootful"];
        default = "rootless";
        description = "Docker daemon mode. 'rootless' runs per-user; 'rootful' runs system-wide.";
      };

      users = mkOption {
        type = listOf str;
        default = [];
        description = "Users to add to the 'docker' group (rootful mode only).";
      };
    }
    # Options from docker-rootless.nix
    // (let
      settingsFormat = pkgs.formats.json {};
    in {
      daemon.settings = mkOption {
        type = settingsFormat.type;
        default = {};
        example = {
          ipv6 = true;
          "fixed-cidr-v6" = "fd00::/80";
        };
        description = ''
          Configuration for docker daemon. The attributes are serialized to JSON used as daemon.conf.
          See https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file
        '';
      };
    });

  config = mkIf cfg.enable (mkMerge [
    {
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv4.conf.all.forwarding" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };
    }

    (mkIf (cfg.mode == "rootless") {
      virtualisation.docker.rootless = {
        enable = true;
        setSocketVariable = true;

        daemon.settings = cfg.daemon.settings;
      };
    })

    (mkIf (cfg.mode == "rootful") (let
      imp = config.capybara.impermanence;
      persistRoot = "${imp.name}/var/lib/docker";
    in {
      virtualisation.docker = {
        enable = true;
        daemon.settings = cfg.daemon.settings;
      };

      users.users = listToAttrs (map (u: {
        name = u;
        value.extraGroups = ["docker"];
      }) cfg.users);

      systemd.tmpfiles.rules = mkIf imp.enable [
        "d ${persistRoot} 0710 root root -"
        "L+ /var/lib/docker - - - - ${persistRoot}"
      ];
    }))
  ]);
}
