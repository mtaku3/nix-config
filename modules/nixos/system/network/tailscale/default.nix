{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.network.tailscale;
in {
  options.capybara.system.network.tailscale = with types; {
    enable = mkBoolOpt false "Whether to enable the tailscale";
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      disableTaildrop = true;
    };

    capybara.impermanence.files = [
      "/run/secrets/tailscale_key"
    ];
  };
}
