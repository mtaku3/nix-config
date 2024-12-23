{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.zathura;
in {
  options.capybara.app.desktop.zathura = {
    enable = mkBoolOpt false "Whether to enable the zathura";
  };

  config = mkIf cfg.enable {
    programs.zathura = enabled;
  };
}
