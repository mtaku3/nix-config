{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.docker;
in {
  options.capybara.app.dev.docker = with types; {
    enable = mkBoolOpt false "Whether to enable the docker";

    # Options from docker.nix
    storageDriver = mkOption {
      type = types.nullOr (types.enum ["aufs" "btrfs" "devicemapper" "overlay" "overlay2" "zfs"]);
      default = null;
      description = ''
        This option determines which Docker
        [storage driver](https://docs.docker.com/storage/storagedriver/select-storage-driver/)
        to use.
        By default it lets docker automatically choose the preferred storage
        driver.
        However, it is recommended to specify a storage driver explicitly, as
        docker's default varies over versions.

        ::: {.warning}
        Changing the storage driver will cause any existing containers
        and images to become inaccessible.
        :::
      '';
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker = {
      inherit (cfg) storageDriver;

      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
  };
}
