{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.discord;
in {
  options.capybara.app.desktop.discord = {
    enable = mkBoolOpt false "Whether to enable the discord";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.discord];
  };
}
