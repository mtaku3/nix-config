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
      ignoreIP =
        ["192.168.20.0/24"]
        # NetBird peers. Warpgate SSHes to its targets from its own peer on
        # behalf of every user, so one failed login there would lock everyone
        # out; brute-force blocking happens at Warpgate and the proxy instead.
        ++ config.capybara.app.server.netbird.peerRanges;
    };

    environment.systemPackages = with pkgs; [iptables];

    capybara.impermanence.directories = ["/var/lib/fail2ban"];
  };
}
