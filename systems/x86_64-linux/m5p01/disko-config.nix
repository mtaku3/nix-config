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
            options = {
              mountpoint = "legacy";
              # etcd lives here (/persist/var/lib/etcd via impermanence) and is the
              # fsync-sensitive workload. atime=off kills access-time write churn;
              # recordsize=16k cuts copy-on-write read-modify-write amplification on
              # etcd's small boltdb pages. NOTE: disko only applies these at initial
              # provisioning. On a live pool set them by hand with `zfs set` (runbook).
              atime = "off";
              recordsize = "16k";
            };
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
