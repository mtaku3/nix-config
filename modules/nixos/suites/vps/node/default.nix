{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.suites.vps.node;
in {
  imports = [../common.nix];

  options.capybara.suites.vps.node = with types; {
    enable = mkBoolOpt false "Whether to enable the vps-node suite";
  };

  config =
    mkIf cfg.enable {
    };
}
