{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.impermanence;
in {
  options.capybara.impermanence = {
    enable = mkBoolOpt false "Whether to enable the impermanence";

    # options from impermanence home-manager.nix
    name = mkOpt types.str "" ''
      A set of persistent storage location submodules listing the
      files and directories to link to their respective persistent
      storage location.

      Each attribute name should be the path relative to the user's
      home directory.

      For detailed usage, check the <link
      xlink:href="https://github.com/nix-community/impermanence">documentation</link>.
    '';

    directories = mkOption {
      type = with types;
        listOf (either str (submodule {
          options = {
            directory = mkOption {
              type = str;
              default = null;
              description = "The directory path to be linked.";
            };
            method = mkOption {
              type = types.enum ["bindfs" "symlink"];
              default = "bindfs";
              description = ''
                The linking method that should be used for this
                directory. bindfs is the default and works for most use
                cases, however some programs may behave better with
                symlinks.
              '';
            };
          };
        }));
      default = [];
      example = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        "VirtualBox VMs"
        ".gnupg"
        ".ssh"
        ".local/share/keyrings"
        ".local/share/direnv"
        {
          directory = ".local/share/Steam";
          method = "symlink";
        }
      ];
      description = ''
        A list of directories in your home directory that
        you want to link to persistent storage. You may optionally
        specify the linking method each directory should use.
      '';
    };

    files = mkOption {
      type = with types; listOf str;
      default = [];
      example = [
        ".screenrc"
      ];
      description = ''
        A list of files in your home directory you want to
        link to persistent storage.
      '';
    };

    allowOther = mkOption {
      type = with types; nullOr bool;
      default = null;
      example = true;
      apply = x:
        if x == null
        then
          warn ''
            home.persistence."${cfg.name}".allowOther not set; assuming 'false'.
            See https://github.com/nix-community/impermanence#home-manager for more info.
          ''
          false
        else x;
      description = ''
        Whether to allow other users, such as
        <literal>root</literal>, access to files through the
        bind mounted directories listed in
        <literal>directories</literal>. Requires the NixOS
        configuration parameter
        <literal>programs.fuse.userAllowOther</literal> to
        be <literal>true</literal>.
      '';
    };

    removePrefixDirectory = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Note: This is mainly useful if you have a dotfiles
        repo structured for use with GNU Stow; if you don't,
        you can likely ignore it.

        Whether to remove the first directory when linking
        or mounting; e.g. for the path
        <literal>"screen/.screenrc"</literal>, the
        <literal>screen/</literal> is ignored for the path
        linked to in your home directory.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.persistence.${cfg.name} = {
      persistentStoragePath = cfg.name;
      directories = cfg.directories;
      files = cfg.files;
      allowOther = cfg.allowOther;
      removePrefixDirectory = cfg.removePrefixDirectory;
    };
  };
}
