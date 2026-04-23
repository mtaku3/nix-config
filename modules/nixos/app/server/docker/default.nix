{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.docker;
in {
  options.capybara.app.server.docker = with types; {
    enable = mkBoolOpt false "Whether to enable the docker";
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        dns = [ "1.1.1.1" "8.8.8.8" ];
      };
    };

    capybara.impermanence.directories = [
      "/var/lib/docker"
    ];
  };
}
