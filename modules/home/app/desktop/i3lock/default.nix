{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.i3lock;
in {
  options.capybara.app.desktop.i3lock = {
    enable = mkBoolOpt false "Whether to enable the i3lock";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.i3lock];
  };
}
