{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.git;
in {
  options.capybara.app.dev.git = {
    enable = mkBoolOpt false "Whether to enable the git";
    username = mkOpt types.str null "Name to configure git with";
    email = mkOpt types.str null "Email to configure git with";
    signingKey = mkOpt types.str null "GPG key to sign commits with";
    signByDefault = mkBoolOpt true "Whether to sign commits by default";
  };

  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      userName = cfg.username;
      userEmail = cfg.email;
      signing = {
        key = cfg.signingKey;
        inherit (cfg) signByDefault;
      };
      extraConfig = {
        init = {defaultBranch = "main";};
        pull = {rebase = true;};
        push = {autoSetupRemote = true;};
      };
    };
  };
}
