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
    agenix.homeManagerModules.default
  ];

  options.capybara.agenix = with types; {
    enable = mkBoolOpt false "Whether to enable the agenix";
  };

  config = mkIf cfg.enable {
    age = {
      identityPaths = ["/persist/var/lib/agenix/agenix_ed25519"];
      secretsDir = "${config.home.homeDirectory}/.agenix";
      secrets = let
        base-path = snowfall.fs.get-file "secrets/${system}/${host}/users/${config.snowfallorg.user.name}";
        prefix-to-remove = "${base-path}/";
      in
        foldl (acc: path:
          if snowfall.path.has-file-extension "age" path
          then acc // {${removePrefix prefix-to-remove (removeSuffix ".age" (builtins.unsafeDiscardStringContext path))}.file = path;}
          else acc) {} (snowfall.fs.get-files-recursive base-path);
    };
  };
}

