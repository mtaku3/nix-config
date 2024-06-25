{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.obsidian;
in {
  options.capybara.app.desktop.obsidian = {
    enable = mkBoolOpt false "Whether to enable the obsidian";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.obsidian];
  };
}
