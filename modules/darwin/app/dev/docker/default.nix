{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.docker;
in {
  options.capybara.app.dev.docker = {
    enable = mkBoolOpt false "Whether to enable the docker";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homebrew.enable;
        message = "Homebrew has to be enabled to install this";
      }
    ];

    homebrew.brews = ["docker" "colima"];
  };
}
