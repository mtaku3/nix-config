{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.system.thunderbolt;
in {
  options.capybara.app.system.thunderbolt = with types; {
    enable = mkBoolOpt false "Whether to enable the thunderbolt";
  };

  config = mkIf cfg.enable {
    services.hardware.bolt.enable = true;
  };
}
