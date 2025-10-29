{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.tailscale;
in {
  options.capybara.app.server.tailscale = with types; {
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
