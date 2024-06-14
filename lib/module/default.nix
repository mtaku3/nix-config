{lib, ...}:
with lib; rec {
  mkOpt = type: default: description: mkOption {inherit type default description;};
  mkBoolOpt = mkOpt types.bool;
  enabled = {enable = true;};
  disabled = {enable = false;};
  userConfigs = config: let
    usernames = attrNames config.snowfallorg.users;
  in
    foldl (acc: username: acc // {"${username}" = config.snowfallorg.users.${username}.home.config;}) {} usernames;
}
