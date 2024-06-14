{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.devenv;
in {
  options.capybara.app.dev.devenv = {
    enable = mkBoolOpt false "Whether to enable the devenv";
  };

  imports = [
    ./direnv.nix
  ];

  config = mkIf cfg.enable {
    home.packages = [pkgs.devenv];
  };
}
