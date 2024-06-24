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
  };

  config = mkIf cfg.enable {
    networking.networkmanager.enable = true;

    capybara.impermanence.directories = [
      "/etc/NetworkManager/system-connections"
    ];
  };
}
