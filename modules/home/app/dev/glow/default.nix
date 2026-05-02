{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.glow;
in {
  options.capybara.app.dev.glow = {
    enable = mkBoolOpt false "Whether to enable glow markdown viewer";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.glow];
  };
}
