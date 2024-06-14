{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.user;
  usernames = attrNames config.snowfallorg.users;
  create-config = acc: username: let
    userConfig = (userConfigs config)."${username}";
  in
    acc
    // {
      ${username} = {
        hashedPasswordFile = config.age.secrets."users/mtaku3/password".path;
        shell =
          if userConfig.capybara.app.dev.zsh.enable
          then userConfig.capybara.app.dev.zsh.package
          else pkgs.shadow;
      };
    };
in {
  options.capybara.user = {
    enable = mkBoolOpt false "Whether to enable the user configurations";
  };

  config = mkIf cfg.enable {
    users.users = foldl create-config {} usernames;
  };
}
