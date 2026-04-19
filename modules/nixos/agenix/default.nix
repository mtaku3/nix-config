{
  lib,
  config,
  inputs,
  host,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.agenix;
in {
  imports = with inputs; [
    agenix.nixosModules.default
  ];

  options.capybara.agenix = with types; {
    enable = mkBoolOpt false "Whether to enable the agenix";
    hostPubkeys = mkOpt (listOf str) [] "Age recipient public keys for this host";
  };

  config = mkIf cfg.enable {
    age = {
      identityPaths = let
        prefix =
          if config.capybara.impermanence.enable
          then config.capybara.impermanence.name
          else "";
      in ["${prefix}/var/lib/agenix/${host}"];
      secrets = let
        mkSecrets = prefix: files:
          foldl (acc: path:
            if snowfall.path.has-file-extension "age" path
            then
              acc
              // {
                ${removePrefix prefix (removeSuffix ".age" (builtins.unsafeDiscardStringContext path))}.file = path;
              }
            else acc) {}
          files;
        common-base = snowfall.fs.get-file "secrets/common";
        host-base = snowfall.fs.get-file "secrets/${host}/system";
        common-files =
          if builtins.pathExists common-base
          then snowfall.fs.get-files-recursive common-base
          else [];
        host-files =
          if builtins.pathExists host-base
          then snowfall.fs.get-files-recursive host-base
          else [];
      in
        (mkSecrets "${common-base}/" common-files)
        // (mkSecrets "${host-base}/" host-files);
    };

    capybara.impermanence.directories = mkIf config.capybara.impermanence.enable [
      "/var/lib/agenix"
    ];
  };
}
