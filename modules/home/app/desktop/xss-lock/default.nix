{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.xss-lock;
in {
  options.capybara.app.desktop.xss-lock = {
    enable = mkBoolOpt false "Whether to enable the xss-lock";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.xss-lock];
  };
}
