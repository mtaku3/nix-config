{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.xserver.xrdp;
in {
  options.capybara.xserver.xrdp = with types; {
    enable = mkBoolOpt false "Whether to enable the xrdp";
  };

  config = mkIf cfg.enable {
    services.xrdp = {
      enable = true;
      openFirewall = true;
      defaultWindowManager = "exec ~/.xrdp.sh";
    };
  };
}
