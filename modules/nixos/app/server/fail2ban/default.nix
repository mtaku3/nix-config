{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.fail2ban;
in {
  options.capybara.app.server.fail2ban = with types; {
    enable = mkBoolOpt false "Whether to enable the fail2ban";
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      ignoreIP = ["192.168.20.0/24"];
    };

    environment.systemPackages = with pkgs; [iptables];

    capybara.impermanence.directories = ["/var/lib/fail2ban"];
  };
}
