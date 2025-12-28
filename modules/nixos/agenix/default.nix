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
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.capybara.impermanence.enable;
        message = "agenix module depends on impermanence";
      }
    ];

    age = {
      identityPaths = ["/persist/var/lib/agenix/${host}"];
      secrets = let
        base-path = snowfall.fs.get-file "secrets/${host}/system";
        prefix-to-remove = "${base-path}/";
      in
        foldl (acc: path:
          if snowfall.path.has-file-extension "age" path
          then acc // {${removePrefix prefix-to-remove (removeSuffix ".age" (builtins.unsafeDiscardStringContext path))}.file = path;}
          else acc) {} (snowfall.fs.get-files-recursive base-path);
    };

    capybara.impermanence.directories = [
      "/var/lib/agenix"
    ];
  };
}
