{
  lib,
  config,
  pkgs,
  host,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.gpg;
  subKeyPath =
    if cfg.importSubkeys
    then config.age.secrets."gpg/sub.key".path or ""
    else "";
in {
  options.capybara.app.dev.gpg = {
    enable = mkBoolOpt false "Whether to enable the gpg";
    importSubkeys = mkBoolOpt false "Import GPG subkeys from agenix on activation";
    keyId = mkOpt types.str "" "Long GPG key id / fingerprint to import";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.gpg = enabled;
      services.gpg-agent = {
        enable = true;
        pinentry.package = pkgs.pinentry-curses;
      };
      capybara.impermanence.directories = [".gnupg"];
    }
    (mkIf cfg.importSubkeys {
      assertions = [
        {
          assertion = config.capybara.agenix.enable;
          message = "capybara.app.dev.gpg.importSubkeys requires capybara.agenix.enable = true";
        }
        {
          assertion = cfg.keyId != "";
          message = "capybara.app.dev.gpg.importSubkeys requires keyId to be set";
        }
      ];

      home.activation.importGpgSubkeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
        SUB_KEY_PATH=${escapeShellArg subKeyPath}
        KEY_ID=${escapeShellArg cfg.keyId}
        if [ ! -r "$SUB_KEY_PATH" ]; then
          echo "gpg import: $SUB_KEY_PATH not readable yet, skipping" >&2
        elif ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null \
             | grep -q '^sec'; then
          : "already imported"
        else
          echo "gpg import: importing subkeys for $KEY_ID" >&2
          ${pkgs.gnupg}/bin/gpg --import "$SUB_KEY_PATH" || \
            echo "gpg import: failed (will retry next activation)" >&2
          if ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null \
             | grep -q '^sec'; then
            FPR=$(${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons --with-fingerprint \
                  "$KEY_ID" | ${pkgs.gawk}/bin/awk -F: '$1=="fpr"{print $10; exit}')
            printf '%s:6:\n' "$FPR" \
              | ${pkgs.gnupg}/bin/gpg --import-ownertrust 2>/dev/null || true
          fi
        fi
      '';
    })
  ]);
}
