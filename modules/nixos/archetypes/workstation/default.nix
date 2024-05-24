{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.archetypes.workstation;
in {
  options.capybara.archetypes.workstation = with types; {
    enable = mkBoolOpt false "Whether to enable the workstation archetype";
  };

  config = mkIf cfg.enable {
    capybara = {
      suites = {
        common = enabled;
        desktop = enabled;
      };
    };
  };
}
