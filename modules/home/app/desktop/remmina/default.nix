{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.remmina;
in {
  options.capybara.app.desktop.remmina = {
    enable = mkBoolOpt false "Whether to enable the remmina";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.remmina];
    capybara.impermanence.directories = [".local/share/remmina"];
  };
}
