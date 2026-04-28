{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  user-names = builtins.attrNames config.snowfallorg.users;
  zshEnabled = any (name: config.home-manager.users.${name}.capybara.app.dev.zsh.enable) user-names;
in {
  config = mkIf zshEnabled {
    environment.etc."zshrc".text = ''
      ${optionalString config.homebrew.enable "eval \"$(${config.homebrew.brewPrefix}/brew shellenv)\""}
    '';
  };
}
