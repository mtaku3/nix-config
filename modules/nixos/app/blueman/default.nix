{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.blueman;
in {
  options.capybara.app.blueman = with types; {
    enable = mkBoolOpt false "Whether to enable the blueman";
  };

  config = mkIf cfg.enable {
    services.blueman = enabled;
  };
}
