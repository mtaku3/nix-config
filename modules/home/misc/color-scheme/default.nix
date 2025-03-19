{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.misc.color-scheme;
in {
  options.capybara.misc.color-scheme = mkOpt (types.enum ["light" "dark"]) "dark" "Color scheme preference (light or dark)";

  config = {
    home.sessionVariables = {
      GTK_THEME = "Adwaita" + (optionalString (cfg == "dark") ":dark");
      QT_STYLE_OVERRIDE = "${cfg}";
    };
  };
}
