{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.docker;
in {
  options.capybara.app.server.docker = with types; {
    enable = mkBoolOpt false "Whether to enable the docker";
  };

  config = mkIf cfg.enable {
    virtualisation.docker = enabled;

    capybara.impermanence.directories = [
      "/var/lib/docker"
    ];
  };
}
