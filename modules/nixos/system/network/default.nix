{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.network;
in {
  options.capybara.system.network = with types; {
    enable = mkBoolOpt false "Whether to enable the network";
    resolved = mkBoolOpt false "Whether to resolve through systemd-resolved (needed for NetBird's per-domain DNS)";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      networking.networkmanager.enable = true;

      capybara.impermanence.directories = [
        "/etc/NetworkManager/system-connections"
      ];
    }
    (mkIf cfg.resolved {
      # networking.nameservers become resolved's global DNS servers.
      services.resolved = {
        enable = true;
        llmnr = "false";
      };
      networking.networkmanager.dns = "systemd-resolved";
    })
  ]);
}
