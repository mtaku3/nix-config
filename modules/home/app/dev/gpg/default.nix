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

      systemd.user.services.import-gpg-subkeys = {
        Unit = {
          Description = "Import GPG subkeys from agenix";
          After = ["agenix.service"];
          Requires = ["agenix.service"];
        };
        Install.WantedBy = ["default.target"];
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = let
            script = pkgs.writeShellScript "import-gpg-subkeys" ''
              set -eu
              SUB_KEY_PATH=${escapeShellArg subKeyPath}
              KEY_ID=${escapeShellArg cfg.keyId}
              if [ ! -r "$SUB_KEY_PATH" ]; then
                echo "gpg import: $SUB_KEY_PATH not readable, aborting" >&2
                exit 1
              fi
              if ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null \
                 | grep -q '^sec'; then
                echo "gpg import: $KEY_ID already present" >&2
                exit 0
              fi
              echo "gpg import: importing subkeys for $KEY_ID" >&2
              ${pkgs.gnupg}/bin/gpg --batch --pinentry-mode loopback \
                --passphrase ''' --import "$SUB_KEY_PATH"
              FPR=$(${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons --with-fingerprint \
                    "$KEY_ID" | ${pkgs.gawk}/bin/awk -F: '$1=="fpr"{print $10; exit}')
              [ -n "$FPR" ] || { echo "gpg import: key $KEY_ID not found after import" >&2; exit 1; }
              printf '%s:6:\n' "$FPR" | ${pkgs.gnupg}/bin/gpg --import-ownertrust
              # Wrap private keys at rest with an empty passphrase so future
              # signs don't trigger pinentry's "set new passphrase" dialog.
              echo wrap | ${pkgs.gnupg}/bin/gpg --batch --pinentry-mode loopback \
                --passphrase ''' --local-user "$FPR" --sign >/dev/null
            '';
          in "${script}";
        };
      };
    })
  ]);
}
