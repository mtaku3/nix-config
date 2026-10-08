{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.gogcli;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  # Linux hosts have no Secret Service, so tokens go to gog's encrypted file
  # keyring, whose password is read from keyringPasswordFile unless the caller
  # already exported one.
  passwordFile = escapeShellArg cfg.keyringPasswordFile;
  readPassword = ''
    if [ -z "''${GOG_KEYRING_PASSWORD-}" ] && [ -r ${passwordFile} ]; then
      GOG_KEYRING_PASSWORD="$(cat ${passwordFile})"
      export GOG_KEYRING_PASSWORD
    fi
  '';

  package = pkgs.symlinkJoin {
    name = "gogcli-wrapped";
    paths = [pkgs.capybara.gogcli];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/gog \
        ${optionalString isLinux "--set-default GOG_KEYRING_BACKEND file"} \
        ${optionalString (cfg.keyringPasswordFile != null) "--run ${escapeShellArg readPassword}"}
    '';
    inherit (pkgs.capybara.gogcli) meta;
  };
in {
  options.capybara.app.dev.gogcli = with types; {
    enable = mkBoolOpt false "Whether to enable gog, the Google Workspace CLI";
    keyringPasswordFile = mkOpt (nullOr str) null "File holding the password of gog's file keyring";
    credentialsSecret = mkOpt (nullOr str) null "Name of the agenix secret holding the default OAuth client as {client_id, client_secret} JSON";
  };

  config = mkIf cfg.enable {
    home.packages = [package];

    # gog reads an OAuth client straight from <data dir>/credentials.json when it
    # carries the secret, so agenix decrypts it there and no keyring is needed.
    age.secrets = mkIf (cfg.credentialsSecret != null) {
      ${cfg.credentialsSecret}.path = "${config.xdg.dataHome}/gogcli/credentials.json";
    };

    capybara.impermanence.directories = optionals isLinux [
      ".config/gogcli"
      ".local/share/gogcli"
    ];
  };
}
