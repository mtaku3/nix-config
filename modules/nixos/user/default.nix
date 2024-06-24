{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  usernames = attrNames config.snowfallorg.users;
  create-config = acc: username: let
    userConfig = (userConfigs config)."${username}";
  in
    acc
    // {
      ${username} = {
        hashedPasswordFile = config.age.secrets."users/${username}@${config.system.name}/password".path;
        shell =
          if userConfig.capybara.app.dev.zsh.enable
          then userConfig.capybara.app.dev.zsh.package
          else pkgs.bash;
      };
    };
in {
  users.users = foldl create-config {} usernames;
}
