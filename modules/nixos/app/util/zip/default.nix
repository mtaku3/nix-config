{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.util.zip;
in {
  options.capybara.app.util.zip = with types; {
    enable = mkBoolOpt false "Whether to enable the zip";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      zip
      unzip
    ];
  };
}
