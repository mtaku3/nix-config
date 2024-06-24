{
  lib,
  config,
  inputs,
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
      in
        foldl (acc: path:
          if snowfall.path.has-file-extension "age" path
          then acc // {${removePrefix "${user-inputs}/secrets/" (removeSuffix ".age" (builtins.unsafeDiscardStringContext path))}.file = path;}
          else acc) {} (snowfall.fs.get-files-recursive "${user-inputs}/secrets");
    };

    capybara.impermanence.files = [
      "/var/lib/agenix/agenix_ed25519"
    ];
  };
}
