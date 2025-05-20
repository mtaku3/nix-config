{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.suites.vps.master;
in {
  imports = [../common.nix];

  options.capybara.suites.vps.master = with types; {
    enable = mkBoolOpt false "Whether to enable the vps-master suite";
  };

  config =
    mkIf cfg.enable {
    };
}
