{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.user;
  usernames = attrNames config.snowfallorg.user;
  create-config = acc: username:
    acc
    // {
      ${username}.initialPassword = "password";
    };
in {
  options.capybara.user = {
    enable = mkBoolOpt false "Whether to enable the user configurations";
  };

  config = mkIf cfg.enable {
    users.users = foldl create-config {} usernames;
  };
}
