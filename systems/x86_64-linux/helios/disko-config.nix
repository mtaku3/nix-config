{
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        postCreateHook = ''
          zfs set mountpoint=none rpool
          zfs list -t snapshot -H -o name | grep -E '^rpool/local/root@blank$' || zfs snapshot rpool/local/root@blank
        '';

        datasets = {
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "local/nix" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
          };
          "local/root" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/";
          };

          "safe" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "safe/persist" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/persist";
          };
          # Home is persisted as a whole instead of through home-manager
          # impermanence. NOTE: disko only creates this at initial provisioning;
          # on a live pool create it by hand with the same options.
          "safe/home" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              acltype = "posixacl";
            };
            mountpoint = "/home";
          };
        };
      };
    };
  };
}
