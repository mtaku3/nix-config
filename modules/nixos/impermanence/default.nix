{
  lib,
  config,
  inputs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.impermanence;
in {
  imports = with inputs; [
    impermanence.nixosModules.impermanence
  ];

  options.capybara.impermanence = with types; ({
      enable = mkBoolOpt false "Whether to enable the impermanence";
    }
    // (let
      defaultPerms = {
        mode = "0755";
        user = "root";
        group = "root";
      };
      commonOpts = {
        options = {
          persistentStoragePath = mkOption {
            type = path;
            default = cfg.name;
            defaultText = "environment.persistence.‹name›.persistentStoragePath";
            description = ''
              The path to persistent storage where the real
              file or directory should be stored.
            '';
          };
          home = mkOption {
            type = nullOr path;
            default = null;
            internal = true;
            description = ''
              The path to the home directory the file is
              placed within.
            '';
          };
          enableDebugging = mkOption {
            type = bool;
            default = cfg.enableDebugging;
            defaultText = "environment.persistence.‹name›.enableDebugging";
            internal = true;
            description = ''
              Enable debug trace output when running
              scripts. You only need to enable this if asked
              to.
            '';
          };
        };
      };
      dirPermsOpts = {
        user = mkOption {
          type = str;
          description = ''
            If the directory doesn't exist in persistent
            storage it will be created and owned by the user
            specified by this option.
          '';
        };
        group = mkOption {
          type = str;
          description = ''
            If the directory doesn't exist in persistent
            storage it will be created and owned by the
            group specified by this option.
          '';
        };
        mode = mkOption {
          type = str;
          example = "0700";
          description = ''
            If the directory doesn't exist in persistent
            storage it will be created with the mode
            specified by this option.
          '';
        };
      };
      fileOpts = {
        options = {
          file = mkOption {
            type = str;
            description = ''
              The path to the file.
            '';
          };
          parentDirectory =
            commonOpts.options
            // mapAttrs
            (_: x:
              if x._type or null == "option"
              then x // {internal = true;}
              else x)
            dirOpts.options;
          filePath = mkOption {
            type = path;
            internal = true;
          };
        };
      };
      dirOpts = {
        options =
          {
            directory = mkOption {
              type = str;
              description = ''
                The path to the directory.
              '';
            };
            hideMount = mkOption {
              type = bool;
              default = cfg.hideMounts;
              defaultText = "environment.persistence.‹name›.hideMounts";
              example = true;
              description = ''
                Whether to hide bind mounts from showing up as
                mounted drives.
              '';
            };
            # Save the default permissions at the level the
            # directory resides. This used when creating its
            # parent directories, giving them reasonable
            # default permissions unaffected by the
            # directory's own.
            defaultPerms = mapAttrs (_: x: x // {internal = true;}) dirPermsOpts;
            dirPath = mkOption {
              type = path;
              internal = true;
            };
          }
          // dirPermsOpts;
      };
      rootFile = submodule [
        commonOpts
        fileOpts
        ({config, ...}: {
          parentDirectory = mkDefault (defaultPerms
            // rec {
              directory = dirOf config.file;
              dirPath = directory;
              inherit (config) persistentStoragePath;
              inherit defaultPerms;
            });
          filePath = mkDefault config.file;
        })
      ];
      rootDir = submodule ([
          commonOpts
          dirOpts
          ({config, ...}: {
            defaultPerms = mkDefault defaultPerms;
            dirPath = mkDefault config.directory;
          })
        ]
        ++ (mapAttrsToList (n: v: {${n} = mkDefault v;}) defaultPerms));
    in {
      # options from impermanence nixos.nix
      name = mkOpt types.str "" ''
        The path to persistent storage where the real
        files and directories should be stored.
      '';

      persistentStoragePath = mkOption {
        type = path;
        defaultText = "‹name›";
        description = ''
          The path to persistent storage where the real
          files and directories should be stored.
        '';
      };

      files = mkOption {
        type = listOf (coercedTo str (f: {file = f;}) rootFile);
        default = [];
        example = [
          "/etc/machine-id"
          "/etc/nix/id_rsa"
        ];
        description = ''
          Files that should be stored in persistent storage.
        '';
      };

      directories = mkOption {
        type = listOf (coercedTo str (d: {directory = d;}) rootDir);
        default = [];
        example = [
          "/var/log"
          "/var/lib/bluetooth"
          "/var/lib/nixos"
          "/var/lib/systemd/coredump"
          "/etc/NetworkManager/system-connections"
        ];
        description = ''
          Directories to bind mount to persistent storage.
        '';
      };

      hideMounts = mkOption {
        type = bool;
        default = false;
        example = true;
        description = ''
          Whether to hide bind mounts from showing up as mounted drives.
        '';
      };

      enableDebugging = mkOption {
        type = bool;
        default = false;
        internal = true;
        description = ''
          Enable debug trace output when running
          scripts. You only need to enable this if asked
          to.
        '';
      };
    }));

  config = mkIf cfg.enable {
    environment.persistence.${cfg.name} = {
      enable = true;
      persistentStoragePath = cfg.name;
      inherit (cfg) files directories hideMounts enableDebugging;
    };

    # Required for home-manager impermanence
    programs.fuse.userAllowOther = true;
  };
}
