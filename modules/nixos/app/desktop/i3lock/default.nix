{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  user-names = builtins.attrNames config.snowfallorg.users;
  i3lockEnabled = any (name: config.home-manager.users.${name}.capybara.app.desktop.i3lock.enable) user-names;
in {
  config = mkIf i3lockEnabled {
    programs.i3lock = enabled;
  };
}
