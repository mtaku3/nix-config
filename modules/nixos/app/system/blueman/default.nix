{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.system.blueman;
in {
  options.capybara.app.system.blueman = with types; {
    enable = mkBoolOpt false "Whether to enable the blueman";
  };

  config = mkIf cfg.enable {
    services.blueman = enabled;
  };
}
