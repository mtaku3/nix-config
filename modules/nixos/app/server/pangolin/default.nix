{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.pangolin;
  yaml = pkgs.formats.yaml {};
  dashboardDomain = "pangolin.${cfg.baseDomain}";

  pangolinConfig = yaml.generate "pangolin-config.yml" {
    gerbil = {
      start_port = 51820;
      base_endpoint = dashboardDomain;
    };
    app = {
      dashboard_url = "https://${dashboardDomain}";
      log_level = "info";
      telemetry.anonymous_usage = false;
    };
    domains.domain1 = {
      base_domain = cfg.baseDomain;
      cert_resolver = "letsencrypt";
      prefer_wildcard_cert = true;
    };
    # server.secret comes from SERVER_SECRET in the agenix env file.
    server.cors = {
      origins = ["https://${dashboardDomain}"];
      methods = ["GET" "POST" "PUT" "DELETE" "PATCH"];
      allowed_headers = ["X-CSRF-Token" "Content-Type"];
      credentials = false;
    };
    flags = {
      require_email_verification = false;
      disable_signup_without_invite = true;
      disable_user_create_org = true;
      allow_raw_resources = true;
    };
  };

  traefikConfig = yaml.generate "traefik_config.yml" {
    api = {
      insecure = true;
      dashboard = true;
    };
    providers = {
      http = {
        endpoint = "http://pangolin:3001/api/v1/traefik-config";
        pollInterval = "5s";
      };
      file.filename = "/etc/traefik/dynamic_config.yml";
    };
    experimental.plugins.badger = {
      moduleName = "github.com/fosrl/badger";
      version = cfg.versions.badger;
    };
    log = {
      level = "INFO";
      format = "common";
    };
    # DNS-01 so the wildcard and two-level names (api.hindsight.…) both issue.
    certificatesResolvers.letsencrypt.acme = {
      email = cfg.acmeEmail;
      storage = "/letsencrypt/acme.json";
      caServer = "https://acme-v02.api.letsencrypt.org/directory";
      dnsChallenge = {
        provider = "cloudflare";
        resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
      };
    };
    entryPoints =
      {
        web.address = ":80";
        websecure = {
          address = ":443";
          transport.respondingTimeouts.readTimeout = "30m";
          http3.advertisedPort = 443;
          http = {
            tls.certResolver = "letsencrypt";
            encodedCharacters = {
              allowEncodedSlash = true;
              allowEncodedQuestionMark = true;
            };
          };
        };
      }
      # Pangolin raw resources bind to entrypoints named tcp-<port>.
      // listToAttrs (map (p: nameValuePair "tcp-${toString p}" {address = ":${toString p}/tcp";}) cfg.tcpPorts);
    serversTransport.insecureSkipVerify = true;
    ping.entryPoint = "web";
  };

  dynamicConfig = yaml.generate "dynamic_config.yml" {
    http = {
      middlewares = {
        badger.plugin.badger.disableForwardAuth = true;
        redirect-to-https.redirectScheme.scheme = "https";
      };
      routers = {
        main-app-router-redirect = {
          rule = "Host(`${dashboardDomain}`)";
          service = "next-service";
          entryPoints = ["web"];
          middlewares = ["redirect-to-https" "badger"];
        };
        next-router = {
          rule = "Host(`${dashboardDomain}`) && !PathPrefix(`/api/v1`)";
          service = "next-service";
          entryPoints = ["websecure"];
          middlewares = ["badger"];
          tls.certResolver = "letsencrypt";
        };
        api-router = {
          rule = "Host(`${dashboardDomain}`) && PathPrefix(`/api/v1`)";
          service = "api-service";
          entryPoints = ["websecure"];
          middlewares = ["badger"];
          tls.certResolver = "letsencrypt";
        };
        ws-router = {
          rule = "Host(`${dashboardDomain}`)";
          service = "api-service";
          entryPoints = ["websecure"];
          middlewares = ["badger"];
          tls.certResolver = "letsencrypt";
        };
      };
      services = {
        next-service.loadBalancer.servers = [{url = "http://pangolin:3002";}];
        api-service.loadBalancer.servers = [{url = "http://pangolin:3000";}];
      };
    };
    tcp.serversTransports = {
      pp-transport-v1.proxyProtocol.version = 1;
      pp-transport-v2.proxyProtocol.version = 2;
    };
  };
in {
  options.capybara.app.server.pangolin = with types; {
    enable = mkBoolOpt false "Whether to enable Pangolin (with Gerbil and Traefik) in Docker";
    baseDomain = mkOpt str "" "Base domain; the dashboard is served at pangolin.<baseDomain>";
    acmeEmail = mkOpt str "" "Let's Encrypt account email";
    tcpPorts = mkOpt (listOf port) [] "Internal TCP entrypoints for raw resources (not published)";
    dataDir = mkOpt str "/var/lib/pangolin" "State directory (SQLite DB, Gerbil key, ACME storage)";
    network = mkOpt str "pangolin" "Docker network shared with other edge containers";
    versions = {
      pangolin = mkOpt str "1.24.0" "fosrl/pangolin image tag";
      gerbil = mkOpt str "1.5.2" "fosrl/gerbil image tag";
      badger = mkOpt str "v1.7.0" "Badger Traefik plugin version";
      traefik = mkOpt str "v3.7" "Traefik image tag";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.baseDomain != "" && cfg.acmeEmail != "";
        message = "capybara.app.server.pangolin.baseDomain and acmeEmail must be set";
      }
    ];

    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        pangolin = {
          image = "docker.io/fosrl/pangolin:${cfg.versions.pangolin}";
          volumes = [
            "${cfg.dataDir}/config:/app/config"
            "${pangolinConfig}:/app/config/config.yml:ro"
          ];
          # SERVER_SECRET=...
          environmentFiles = [config.age.secrets."pangolin/pangolin.env".path];
          networks = [cfg.network];
        };

        gerbil = {
          image = "docker.io/fosrl/gerbil:${cfg.versions.gerbil}";
          cmd = [
            "--reachableAt=http://gerbil:3004"
            "--generateAndSaveKeyTo=/var/config/key"
            "--remoteConfig=http://pangolin:3001/api/v1/"
          ];
          volumes = ["${cfg.dataDir}/config:/var/config"];
          capabilities = {
            NET_ADMIN = true;
            SYS_MODULE = true;
          };
          ports = [
            "51820:51820/udp"
            "21820:21820/udp"
            "443:443"
            "443:443/udp"
            "80:80"
          ];
          networks = [cfg.network];
          dependsOn = ["pangolin"];
        };

        # Shares Gerbil's network namespace, so its ports are Gerbil's.
        traefik = {
          image = "docker.io/traefik:${cfg.versions.traefik}";
          cmd = ["--configFile=/etc/traefik/traefik_config.yml"];
          volumes = [
            "${traefikConfig}:/etc/traefik/traefik_config.yml:ro"
            "${dynamicConfig}:/etc/traefik/dynamic_config.yml:ro"
            "${cfg.dataDir}/config/letsencrypt:/letsencrypt"
          ];
          # CF_DNS_API_TOKEN=...
          environmentFiles = [config.age.secrets."pangolin/traefik.env".path];
          extraOptions = ["--network=container:gerbil"];
          dependsOn = ["gerbil"];
        };
      };
    };

    systemd.services =
      {
        "docker-network-${cfg.network}" = {
          description = "Create the ${cfg.network} Docker network";
          after = ["docker.service"];
          requires = ["docker.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            ${pkgs.docker}/bin/docker network inspect ${cfg.network} >/dev/null 2>&1 \
              || ${pkgs.docker}/bin/docker network create ${cfg.network}
          '';
        };
      }
      // genAttrs ["docker-pangolin" "docker-gerbil"] (_: {
        requires = ["docker-network-${cfg.network}.service"];
        after = ["docker-network-${cfg.network}.service"];
      });

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
      "d ${cfg.dataDir}/config 0700 root root -"
      "d ${cfg.dataDir}/config/letsencrypt 0700 root root -"
    ];

    networking.firewall = {
      allowedTCPPorts = [80 443];
      allowedUDPPorts = [443 51820 21820];
    };

    capybara.impermanence.directories = [cfg.dataDir];
  };
}
