{
  lib,
  config,
  options,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.impermanence;
in {
  options.capybara.impermanence = {
    enable = mkBoolOpt false "Whether to enable the impermanence";

    name = mkOpt types.str "" ''
      The path to persistent storage, e.g. `/persist`. Entries are
      stored under it at the same path as in the home directory, so
      `Downloads` lives in `<name>/home/<user>/Downloads`.

      For detailed usage, check the <link
      xlink:href="https://github.com/nix-community/impermanence">documentation</link>.
    '';

    directories = mkOption {
      type = with types; listOf str;
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
      ];
      description = ''
        A list of directories in your home directory that
        you want to bind mount to persistent storage.
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
  };

  # The impermanence NixOS module imports home.persistence into Home Manager
  # itself, so the option doesn't exist on darwin.
  config = mkIf cfg.enable (optionalAttrs (options.home ? persistence) {
    # Several modules may persist the same path; impermanence rejects duplicates.
    home.persistence.${cfg.name} = {
      directories = unique cfg.directories;
      files = unique cfg.files;
    };
  });
}
