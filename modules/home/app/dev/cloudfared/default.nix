{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.cloudflared;
in {
  options.capybara.app.dev.cloudflared = {
    enable = mkBoolOpt false "Whether to install the cloudflared";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [cloudflared];
    capybara.impermanence.directories = [".cloudflared"];
  };
}
