{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.suites.homelab;
in {
  options.capybara.suites.homelab = with types; {
    enable = mkBoolOpt false "Whether to enable the homelab suite";
  };

  config = mkIf cfg.enable {
    networking.firewall.enable = false;

    capybara = {
      suites.common = enabled;
      app.server = {
        ssh = enabled;
      };
    };
  };
}
