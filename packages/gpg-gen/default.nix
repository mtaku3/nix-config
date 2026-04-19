{
  pkgs,
  lib,
  ...
}: let
  libSh = ./scripts/lib.sh;
  mainSh = ./scripts/main.sh;
in
  pkgs.writeShellApplication {
    name = "gpg-gen";
    runtimeInputs = with pkgs; [gnupg age nix coreutils gnused gawk jq git];
    text = ''
      export GPG_GEN_LIB=${libSh}
      ${builtins.readFile mainSh}
    '';
    meta = {
      description = "Generate a GPG identity (master + E/S/A subkeys) and deploy via agenix or to a directory";
      platforms = lib.platforms.unix;
      mainProgram = "gpg-gen";
    };
  }
