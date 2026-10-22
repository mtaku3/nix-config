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
  peer = "warpgate-netbird";
  nbServer = config.capybara.app.server.netbird-server;

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
      # Every connection comes from the NetBird proxy; without the client
      # address in its PROXY header, one brute-forcing bot would get the
      # proxy's address (everyone) blocked.
      proxy_protocol = true;
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
    network = mkOpt str nbServer.network "Docker network the NetBird peer joins to reach the management server";
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

    # The NetBird proxy only reaches backends through mesh peers, so Warpgate
    # is a peer of its own: it shares the network namespace of a NetBird
    # client container, which owns the namespace so Warpgate restarts keep
    # the peer up. Nothing is published on the host.
    virtualisation.oci-containers = {
      backend = "docker";
      containers.${peer} = {
        image = "docker.io/netbirdio/netbird:${nbServer.versions.netbird}";
        hostname = "warpgate";
        environment.NB_MANAGEMENT_URL = config.capybara.app.server.netbird.managementUrl;
        # NB_SETUP_KEY=... (only used for the first login; state persists)
        environmentFiles = [config.age.secrets."netbird/warpgate-setup-key.env".path];
        volumes = ["${peer}:/var/lib/netbird"];
        networks = [cfg.network];
        capabilities = {
          NET_ADMIN = true;
          SYS_ADMIN = true;
          SYS_RESOURCE = true;
        };
        devices = ["/dev/net/tun"];
      };
      containers.warpgate = {
        inherit image;
        volumes = ["${volume}:/data"];
        dependsOn = [peer];
        extraOptions = ["--network=container:${peer}"];
      };
    };

    systemd.services."docker-${peer}" = {
      requires = ["docker-network-${cfg.network}.service"];
      after = ["docker-network-${cfg.network}.service"];
    };

    systemd.services.docker-warpgate = {
      after = ["warpgate-config.service"];
      # A new peer container is a new namespace; follow it.
      partOf = ["docker-${peer}.service"];
      restartTriggers = [warpgateConfig];
    };
  };
}
