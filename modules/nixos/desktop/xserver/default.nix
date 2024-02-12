{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.xserver;
in {
  options.capybara.desktop.xserver = {
    enable = mkBoolOpt false "Whether to enable the X";
  };

  config = mkIf cfg.enable {
    services.xserver = enabled;
  };
}
