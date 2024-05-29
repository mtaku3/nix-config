{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  zshEnabled = foldl (acc: config: acc || config.capybara.app.dev.zsh.enable) false (attrValues (userConfigs config));
in {
  config = mkIf zshEnabled {
    programs.zsh = enabled;
  };
}
