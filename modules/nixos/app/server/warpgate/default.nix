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
  # warpgate user (uid 1000) and Docker seeds the volume with the image's
  # /data ownership.
  volume = "warpgate-data";
  volumePath = "/var/lib/docker/volumes/${volume}/_data";
  secretPlaceholder = "@GOOGLE_CLIENT_SECRET@";

  tls = {
    certificate = "/data/tls.certificate.pem";
    key = "/data/tls.key.pem";
  };
  disabled = listen: {
    enable = false;
    inherit listen;
  };

  warpgateConfig = (pkgs.formats.yaml {}).generate "warpgate.yaml" {
    external_host = cfg.externalHost;
    database_url = "sqlite:/data/db";
    sso_providers = optional (cfg.google.clientId != "") {
      name = "google";
      label = "Google";
      provider = {
        type = "google";
        client_id = cfg.google.clientId;
        client_secret = secretPlaceholder;
      };
    };
    ssh = {
      enable = true;
      listen = "[::]:2222";
      # Port users dial; Warpgate shows it in connection instructions.
      external_port = cfg.sshPort;
      host_key_verification = "prompt";
      inactivity_timeout = "5m";
    };
    http =
      tls
      // {
        listen = "[::]:8888";
        # The NetBird reverse proxy terminates TLS in front of the web UI, so public
        # URLs (incl. the SSO redirect URI) must say 443, not the listen port.
        external_port = 443;
        trust_x_forwarded_headers = true;
        session_max_age = "30m";
        cookie_max_age = "1day";
      };
    kubernetes = disabled "[::]:8443" // tls;
    mysql = disabled "[::]:33306" // tls;
    postgres = disabled "[::]:55432" // tls;
    vnc = disabled "[::]:5900" // tls;
    log = {
      retention = "7days";
      format = "text";
    };
  };
in {
  options.capybara.app.server.warpgate = with types; {
    enable = mkBoolOpt false "Whether to enable Warpgate (SSH bastion) in Docker";
    externalHost = mkOpt str "" "Public hostname of the Warpgate web UI";
    sshPort = mkOpt port 22 "Public SSH port (shown in connection instructions)";
    publishSsh = mkBoolOpt true "Whether to publish SSH on the host; off when a reverse proxy on the Docker network fronts it";
    network = mkOpt str config.capybara.app.server.netbird-server.network "Docker network to join";
    address = mkOpt str "172.30.0.20" "Static Warpgate address on the Docker network (the NetBird proxy targets it by IP)";
    meshSshPort = mkOpt (nullOr port) null "Host port, open only on the NetBird interface, forwarded to Warpgate SSH (the NetBird proxy's L4 relay can only dial mesh peers)";
    version = mkOpt str "0.30.0" "Warpgate image tag";
    google.clientId = mkOpt str "" "Google OAuth client ID; the secret comes from the warpgate/google-client-secret agenix file";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.externalHost != "";
        message = "capybara.app.server.warpgate.externalHost must be set";
      }
    ];

    # First boot only: create the database, admin user and SSH keys.
    systemd.services.warpgate-setup = {
      description = "Initialise Warpgate database";
      after = ["docker.service"];
      requires = ["docker.service"];
      before = ["warpgate-config.service"];
      requiredBy = ["warpgate-config.service"];
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
            --external-host ${cfg.externalHost}
      '';
    };

    # The config itself is owned by Nix; only the client secret is spliced in.
    systemd.services.warpgate-config = {
      description = "Install Warpgate config";
      before = ["docker-warpgate.service"];
      requiredBy = ["docker-warpgate.service"];
      restartTriggers = [warpgateConfig];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -m 0600 -o 1000 -g 1000 ${warpgateConfig} ${volumePath}/warpgate.yaml
        ${optionalString (cfg.google.clientId != "") ''
          ${pkgs.replace-secret}/bin/replace-secret ${secretPlaceholder} \
            ${config.age.secrets."warpgate/google-client-secret".path} \
            ${volumePath}/warpgate.yaml
        ''}
      '';
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers.warpgate = {
        inherit image;
        volumes = ["${volume}:/data"];
        ports = optional cfg.publishSsh "${toString cfg.sshPort}:2222";
        networks = [cfg.network];
        extraOptions = ["--ip=${cfg.address}"];
      };
    };

    systemd.services.docker-warpgate = {
      requires = ["docker-network-${cfg.network}.service"];
      after = ["docker-network-${cfg.network}.service" "warpgate-config.service"];
      restartTriggers = [warpgateConfig];
    };

    networking.firewall.allowedTCPPorts = optional cfg.publishSsh cfg.sshPort;

    # A Docker-published port would skip the host firewall, so a socket on the
    # host relays to the container instead and is reachable only via NetBird.
    systemd.sockets.warpgate-mesh-ssh = mkIf (cfg.meshSshPort != null) {
      wantedBy = ["sockets.target"];
      listenStreams = [(toString cfg.meshSshPort)];
    };
    systemd.services.warpgate-mesh-ssh = mkIf (cfg.meshSshPort != null) {
      requires = ["docker-warpgate.service"];
      after = ["docker-warpgate.service"];
      serviceConfig.ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${cfg.address}:2222";
    };
    networking.firewall.interfaces.${config.services.netbird.clients.wt0.interface}.allowedTCPPorts =
      optional (cfg.meshSshPort != null) cfg.meshSshPort;
  };
}
