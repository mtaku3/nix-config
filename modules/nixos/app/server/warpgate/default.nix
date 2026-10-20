{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.warpgate;
  docker = "${pkgs.docker}/bin/docker";
  image = "ghcr.io/warp-tech/warpgate:${cfg.version}";
  # Named volume rather than a bind mount: the image runs as the unprivileged
  # warpgate user and Docker seeds the volume with the image's /data ownership.
  volume = "warpgate-data";
in {
  options.capybara.app.server.warpgate = with types; {
    enable = mkBoolOpt false "Whether to enable Warpgate (SSH bastion) in Docker";
    externalHost = mkOpt str "" "Public hostname of the Warpgate web UI";
    sshPort = mkOpt port 22 "Host port published for Warpgate SSH";
    network = mkOpt str config.capybara.app.server.pangolin.network "Docker network to join (Pangolin reaches the UI as warpgate:8888)";
    version = mkOpt str "v0.30.0" "Warpgate image tag";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.externalHost != "";
        message = "capybara.app.server.warpgate.externalHost must be set";
      }
    ];

    # First boot only: generate /data/warpgate.yaml, the admin user and keys.
    # SSO providers and trust_x_forwarded_headers are then edited in that file.
    systemd.services.warpgate-setup = {
      description = "Initialise Warpgate config";
      after = ["docker.service"];
      requires = ["docker.service"];
      before = ["docker-warpgate.service"];
      requiredBy = ["docker-warpgate.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # WARPGATE_ADMIN_PASSWORD=...
        EnvironmentFile = config.age.secrets."warpgate/warpgate.env".path;
      };
      script = ''
        ${docker} run --rm \
          -e WARPGATE_ADMIN_PASSWORD \
          -v ${volume}:/data \
          ${image} unattended-setup \
            --if-config-exists skip \
            --data-path /data \
            --http-port 8888 \
            --ssh-port 2222 \
            --external-host ${cfg.externalHost} \
            --record-sessions
      '';
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers.warpgate = {
        inherit image;
        volumes = ["${volume}:/data"];
        ports = ["${toString cfg.sshPort}:2222"];
        networks = [cfg.network];
      };
    };

    systemd.services.docker-warpgate = {
      requires = ["docker-network-${cfg.network}.service"];
      after = ["docker-network-${cfg.network}.service"];
    };

    networking.firewall.allowedTCPPorts = [cfg.sshPort];
  };
}
