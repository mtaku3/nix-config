{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.system.fprintd;
in {
  options.capybara.app.system.fprintd = with types; {
    enable = mkBoolOpt false "Whether to enable the fprintd";
  };

  config = mkIf cfg.enable {
    services.fprintd = enabled;

    capybara.impermanence.directories = ["/var/lib/fprint"];
  };
}
