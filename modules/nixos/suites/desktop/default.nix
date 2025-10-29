{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.suites.desktop;
in {
  options.capybara.suites.desktop = with types; {
    enable = mkBoolOpt false "Whether to enable the desktop suite";
  };

  config = mkIf cfg.enable {
    capybara = {
      system = {
        audio = enabled;
        network.tailscale = enabled;
      };
      xserver = {
        enable = true;
        greetd = enabled;
      };
      app.util.zip = enabled;
    };
  };
}
