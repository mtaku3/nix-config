{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.docker;
in {
  options.capybara.app.docker = with types; {
    enable = mkBoolOpt false "Whether to enable the docker";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };
}
