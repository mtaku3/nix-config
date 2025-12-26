{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.ssh;
in {
  options.capybara.app.server.ssh = with types; {
    enable = mkBoolOpt false "Whether to enable the ssh";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports = [22];
      settings = {
        PasswordAuthentication = false;
        AllowUsers = null;
        UseDns = true;
        X11Forwarding = false;
        PermitRootLogin = "no";
      };
    };

    age.secrets = {
      "ssh/ssh_host_rsa_key" = {
        path = "/etc/ssh/ssh_host_rsa_key";
        mode = "600";
        owner = "root";
        group = "root";
      };
      "ssh/ssh_host_rsa_key.pub" = {
        path = "/etc/ssh/ssh_host_rsa_key.pub";
        mode = "644";
        owner = "root";
        group = "root";
      };
      "ssh/ssh_host_ed25519_key" = {
        path = "/etc/ssh/ssh_host_ed25519_key";
        mode = "600";
        owner = "root";
        group = "root";
      };
      "ssh/ssh_host_ed25519_key.pub" = {
        path = "/etc/ssh/ssh_host_ed25519_key.pub";
        mode = "644";
        owner = "root";
        group = "root";
      };
    };
  };
}
