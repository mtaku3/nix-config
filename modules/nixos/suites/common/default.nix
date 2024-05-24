{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.suites.common;
in {
  options.capybara.suites.common = with types; {
    enable = mkBoolOpt false "Whether to enable the common suite";
  };

  config = mkIf cfg.enable {
    capybara = {
      user = enabled;

      system = {
        locale = enabled;
        console = enabled;
        fonts = enabled;
      };
    };
  };
}
