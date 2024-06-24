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

  config = mkIf cfg.enable {
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;

      daemon.settings = cfg.daemon.settings;
    };
  };
}
