{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  user-names = builtins.attrNames config.snowfallorg.users;
  create-system-users = system-users: name: let
    user = config.snowfallorg.users.${name};
    cfg = config.home-manager.users.${name};
  in
    system-users
    // (optionalAttrs user.create {
      ${name} = {
        hashedPasswordFile = let
          ageKey = "/users/${name}/password";
        in
          mkIf (builtins.hasAttr ageKey config.age.secrets) config.age.secrets.${ageKey}.path;
        shell = let
          zsh = cfg.capybara.app.dev.zsh;
        in
          mkIf zsh.enable zsh.package;
        ignoreShellProgramCheck = true;
      };
    });
in {
  users.users = foldl create-system-users {} user-names;
}
