{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.hosts;
in {
  options.capybara.system.hosts = with types; {
    enable = mkBoolOpt false "Whether to enable the hosts";
  };

  config = mkIf cfg.enable {
    networking.extraHosts = ''
      192.168.10.2 m5p01 cluster.local
    '';
  };
}
