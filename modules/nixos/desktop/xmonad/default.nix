{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  enabled = foldl (acc: config: acc || config.capybara.desktop.xmonad.enable) false (attrValues (userConfigs config));
in {
  config =
    mkIf enabled {
    };
}
