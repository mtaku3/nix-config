{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.docker;
in {
  options.capybara.app.dev.docker = with types; {
    enable = mkBoolOpt false "Whether to enable the docker";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };
}
