{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.power.do-not-sleep;
in {
  options.capybara.system.power.do-not-sleep = with types; {
    enable = mkBoolOpt false "Whether not to sleep on lid close if AC is connected";
  };

  config = mkIf cfg.enable {
    services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
  };
}
