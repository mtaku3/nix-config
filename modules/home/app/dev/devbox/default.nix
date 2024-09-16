{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.devbox;
in {
  options.capybara.app.dev.devbox = {
    enable = mkBoolOpt false "Whether to enable the devbox";
  };

  imports = [
    ./direnv.nix
  ];

  config = mkIf cfg.enable {
    home.packages = [pkgs.unstable.devbox];
  };
}
