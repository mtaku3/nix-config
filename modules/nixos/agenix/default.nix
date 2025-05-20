{
  lib,
  config,
  inputs,
  system,
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
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.capybara.impermanence.enable;
        message = "agenix module depends on impermanence";
      }
    ];

    age = {
      identityPaths = ["/persist/var/lib/agenix/agenix_ed25519"];
      secrets = let
        user-inputs = snowfall.fs.get-file "";
        base-path = "${user-inputs}/secrets/${system}/${host}";
      in
        foldl (acc: path:
          if snowfall.path.has-file-extension "age" path
          then acc // {${removePrefix base-path (removeSuffix ".age" (builtins.unsafeDiscardStringContext path))}.file = path;}
          else acc) {} (snowfall.fs.get-files-recursive base-path);
    };

    capybara.impermanence.files = [
      "/var/lib/agenix/agenix_ed25519"
    ];
  };
}
