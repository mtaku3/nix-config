{
  lib,
  config,
  host,
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
        openssh.authorizedKeys.keys = cfg.capybara.openssh.keys;
      };
    });
in {
  users.users = foldl create-system-users {} user-names;
}
