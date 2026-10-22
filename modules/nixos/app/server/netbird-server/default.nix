{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.netbird-server;
  yaml = pkgs.formats.yaml {};
  docker = "${pkgs.docker}/bin/docker";
  proxyUid = 1000; # the reverse-proxy image runs as uid/gid 1000
  tls.certResolver = "letsencrypt";

  # Secret name under netbird/ -> placeholder in the rendered config.
  placeholders = {
    auth-secret = "@NETBIRD_AUTH_SECRET@";
    session-cookie-key = "@NETBIRD_SESSION_COOKIE_KEY@";
    datastore-key = "@NETBIRD_DATASTORE_KEY@";
  };

  # Combined server: management + signal + relay + STUN + embedded IdP (Dex).
  serverConfig = yaml.generate "netbird-config.yaml" {
    server = {
      listenAddress = ":80";
      exposedAddress = "https://${cfg.domain}:443";
      stunPorts = [cfg.stunPort];
      metricsPort = 9090;
      healthcheckAddress = ":9000";
      logLevel = "info";
      logFile = "console";
      authSecret = placeholders.auth-secret;
      dataDir = "/var/lib/netbird";
      auth = {
        issuer = "https://${cfg.domain}/oauth2";
        signKeyRefreshEnabled = true;
        sessionCookieEncryptionKey = placeholders.session-cookie-key;
        dashboardRedirectURIs = [
          "https://${cfg.domain}/nb-auth"
          "https://${cfg.domain}/nb-silent-auth"
        ];
        cliRedirectURIs = ["http://localhost:53000/"];
      };
      reverseProxy.trustedHTTPProxies = ["${cfg.traefikAddress}/32"];
      store = {
        engine = "sqlite";
        encryptionKey = placeholders.datastore-key;
      };
    };
  };

  # Traefik terminates TLS for the NetBird domain and any extra httpRoutes, and
  # passes every other SNI through to the proxy, which gets its own certificates.
  traefikDynamic = yaml.generate "traefik-dynamic.yaml" ({
      http = {
        routers =
          {
            netbird-grpc = {
              rule = "Host(`${cfg.domain}`) && (PathPrefix(`/signalexchange.SignalExchange/`) || PathPrefix(`/management.ManagementService/`) || PathPrefix(`/management.ProxyService/`))";
              service = "netbird-server-h2c";
              entryPoints = ["websecure"];
              inherit tls;
              priority = 100;
            };
            netbird-backend = {
              rule = "Host(`${cfg.domain}`) && (PathPrefix(`/relay`) || PathPrefix(`/ws-proxy/`) || PathPrefix(`/api`) || PathPrefix(`/oauth2`))";
              service = "netbird-server";
              entryPoints = ["websecure"];
              inherit tls;
              priority = 100;
            };
            netbird-dashboard = {
              rule = "Host(`${cfg.domain}`)";
              service = "netbird-dashboard";
              entryPoints = ["websecure"];
              inherit tls;
              priority = 1;
            };
          }
          // mapAttrs' (host: _:
            nameValuePair "route-${host}" {
              rule = "Host(`${host}`)";
              service = "route-${host}";
              entryPoints = ["websecure"];
              inherit tls;
            })
          cfg.httpRoutes;
        services =
          {
            netbird-server.loadBalancer.servers = [{url = "http://netbird-server:80";}];
            netbird-server-h2c.loadBalancer.servers = [{url = "h2c://netbird-server:80";}];
            netbird-dashboard.loadBalancer.servers = [{url = "http://netbird-dashboard:80";}];
          }
          // mapAttrs' (host: url:
            nameValuePair "route-${host}" {
              loadBalancer = {
                servers = [{inherit url;}];
                # Backends such as Warpgate serve self-signed TLS.
                serversTransport = "insecure";
              };
            })
          cfg.httpRoutes;
        serversTransports.insecure.insecureSkipVerify = true;
      };
    }
    // optionalAttrs cfg.proxy.enable {
      tcp = {
        routers.proxy-passthrough = {
          entryPoints = ["websecure"];
          rule = "HostSNI(`*`)";
          service = "proxy-tls";
          tls.passthrough = true;
          priority = 1;
        };
        services.proxy-tls.loadBalancer = {
          servers = [{address = "netbird-proxy:8443";}];
          serversTransport = "pp-v2";
        };
        serversTransports.pp-v2.proxyProtocol.version = 2;
      };
    });

  l4Ports = proto: map (p: "${toString p}:${toString p}/${proto}");
in {
  options.capybara.app.server.netbird-server = with types; {
    enable = mkBoolOpt false "Whether to enable the self-hosted NetBird server (with dashboard and Traefik) in Docker";
    baseDomain = mkOpt str "" "Parent domain of the dashboard and the proxied services";
    domain = mkOpt str "netbird.${cfg.baseDomain}" "Hostname of the dashboard and management API";
    acmeEmail = mkOpt str "" "Let's Encrypt account email";
    stunPort = mkOpt port 3478 "Public UDP port for STUN";
    httpRoutes = mkOpt (attrsOf str) {} "Extra hostnames Traefik terminates and forwards to a backend URL";
    dataDir = mkOpt str "/var/lib/netbird-server" "State directory (SQLite store, rendered config, ACME storage)";
    network = mkOpt str "netbird" "Docker network shared with other edge containers";
    subnet = mkOpt str "172.30.0.0/24" "Subnet of the Docker network";
    traefikAddress = mkOpt str "172.30.0.10" "Static Traefik address on the Docker network (trusted for forwarded headers)";

    proxy = {
      enable = mkBoolOpt false "Whether to run the NetBird reverse proxy (needs the netbird/proxy.env token)";
      domain = mkOpt str cfg.baseDomain "Base domain of the proxy cluster; services are published as subdomains of it";
      wireguardPort = mkOpt port 51820 "UDP port of the proxy's embedded WireGuard peer";
      # Community blocklists from a local CrowdSec LAPI; enforced per service
      # (Access Control → CrowdSec IP Reputation).
      crowdsec = mkBoolOpt false "Whether to run a CrowdSec LAPI the proxy checks client IPs against";
      private = mkBoolOpt true "Whether NetBird peers can reach NetBird-only services through the tunnel (adds per-account tunnel listeners; public services are unaffected)";
      tcpPorts = mkOpt (listOf port) [] "Public ports for TCP-mode services";
      udpPorts = mkOpt (listOf port) [] "Public ports for UDP-mode services";
    };

    versions = {
      netbird = mkOpt str "0.81.3" "netbird-server and reverse-proxy image tag";
      dashboard = mkOpt str "v2.95.0" "Dashboard image tag";
      traefik = mkOpt str "v3.7.16" "Traefik image tag";
      crowdsec = mkOpt str "v1.8.1" "CrowdSec image tag";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.baseDomain != "" && cfg.acmeEmail != "";
        message = "capybara.app.server.netbird-server.baseDomain and acmeEmail must be set";
      }
    ];

    systemd.services = mkMerge [
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
            ${docker} network inspect ${cfg.network} >/dev/null 2>&1 \
              || ${docker} network create --subnet ${cfg.subnet} ${cfg.network}
          '';
        };

        # The config is owned by Nix; only the secrets are spliced in.
        netbird-server-config = {
          description = "Install NetBird server config";
          before = ["docker-netbird-server.service"];
          requiredBy = ["docker-netbird-server.service"];
          restartTriggers = [serverConfig];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            install -m 0600 ${serverConfig} ${cfg.dataDir}/config.yaml
            ${concatStringsSep "\n" (mapAttrsToList (name: placeholder: ''
                ${pkgs.replace-secret}/bin/replace-secret ${placeholder} \
                  ${config.age.secrets."netbird/${name}".path} ${cfg.dataDir}/config.yaml
              '')
              placeholders)}
          '';
        };

        docker-netbird-server.restartTriggers = [serverConfig];
        # The state dir is an impermanence bind mount that Docker may have
        # created as root before tmpfiles ran; the proxy runs as uid 1000.
        docker-netbird-proxy.preStart = mkIf cfg.proxy.enable ''
          install -d -m 0750 -o ${toString proxyUid} -g ${toString proxyUid} ${cfg.dataDir}/proxy-certs
        '';
        docker-netbird-traefik.restartTriggers = [traefikDynamic];
      }
      (genAttrs (map (n: "docker-${n}") (["netbird-server" "netbird-dashboard" "netbird-traefik"]
        ++ optional cfg.proxy.enable "netbird-proxy"
        ++ optional (cfg.proxy.enable && cfg.proxy.crowdsec) "netbird-crowdsec")) (_: {
        requires = ["docker-network-${cfg.network}.service"];
        after = ["docker-network-${cfg.network}.service"];
      }))
    ];

    virtualisation.oci-containers = {
      backend = "docker";
      containers =
        {
          netbird-server = {
            image = "docker.io/netbirdio/netbird-server:${cfg.versions.netbird}";
            cmd = ["--config" "/etc/netbird/config.yaml"];
            volumes = [
              "${cfg.dataDir}/data:/var/lib/netbird"
              "${cfg.dataDir}/config.yaml:/etc/netbird/config.yaml:ro"
            ];
            ports = ["${toString cfg.stunPort}:${toString cfg.stunPort}/udp"];
            networks = [cfg.network];
          };

          netbird-dashboard = {
            image = "docker.io/netbirdio/dashboard:${cfg.versions.dashboard}";
            environment = {
              NETBIRD_MGMT_API_ENDPOINT = "https://${cfg.domain}";
              NETBIRD_MGMT_GRPC_API_ENDPOINT = "https://${cfg.domain}";
              AUTH_AUDIENCE = "netbird-dashboard";
              AUTH_CLIENT_ID = "netbird-dashboard";
              AUTH_CLIENT_SECRET = "";
              AUTH_AUTHORITY = "https://${cfg.domain}/oauth2";
              USE_AUTH0 = "false";
              AUTH_SUPPORTED_SCOPES = "openid profile email groups";
              AUTH_REDIRECT_URI = "/nb-auth";
              AUTH_SILENT_REDIRECT_URI = "/nb-silent-auth";
              NGINX_SSL_PORT = "443";
              LETSENCRYPT_DOMAIN = "none";
            };
            networks = [cfg.network];
          };

          netbird-traefik = {
            image = "docker.io/traefik:${cfg.versions.traefik}";
            cmd = [
              "--log.level=INFO"
              "--accesslog=true"
              "--providers.file.filename=/etc/traefik/dynamic.yaml"
              "--entrypoints.web.address=:80"
              "--entrypoints.websecure.address=:443"
              "--entrypoints.websecure.allowACMEByPass=true"
              "--entrypoints.web.http.aliasHeadersStrategy=delete"
              "--entrypoints.websecure.http.aliasHeadersStrategy=delete"
              # Long-lived gRPC streams
              "--entrypoints.websecure.transport.respondingTimeouts.readTimeout=0"
              "--entrypoints.websecure.transport.respondingTimeouts.writeTimeout=0"
              "--entrypoints.websecure.transport.respondingTimeouts.idleTimeout=0"
              "--serverstransport.forwardingtimeouts.responseheadertimeout=0s"
              "--serverstransport.forwardingtimeouts.idleconntimeout=0s"
              "--entrypoints.web.http.redirections.entrypoint.to=websecure"
              "--entrypoints.web.http.redirections.entrypoint.scheme=https"
              # DNS-01, so certificates issue before the public route points here.
              "--certificatesresolvers.letsencrypt.acme.email=${cfg.acmeEmail}"
              "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
              "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"
              "--certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=1.1.1.1:53,1.0.0.1:53"
            ];
            volumes = [
              "${traefikDynamic}:/etc/traefik/dynamic.yaml:ro"
              "${cfg.dataDir}/letsencrypt:/letsencrypt"
            ];
            # CF_DNS_API_TOKEN=...
            environmentFiles = [config.age.secrets."netbird/cloudflare.env".path];
            ports = ["80:80" "443:443"];
            networks = [cfg.network];
            extraOptions = ["--ip=${cfg.traefikAddress}"];
          };
        }
        // optionalAttrs cfg.proxy.enable {
          netbird-proxy = {
            image = "docker.io/netbirdio/reverse-proxy:${cfg.versions.netbird}";
            environment =
              {
                NB_PROXY_DEBUG_LOGS = "false";
                # Internal network, so the proxy never depends on the public route.
                NB_PROXY_MANAGEMENT_ADDRESS = "http://netbird-server:80";
                NB_PROXY_ALLOW_INSECURE = "true";
                NB_PROXY_DOMAIN = cfg.proxy.domain;
                NB_PROXY_ADDRESS = ":8443";
                NB_PROXY_WG_PORT = toString cfg.proxy.wireguardPort;
                NB_PROXY_PRIVATE = boolToString cfg.proxy.private;
                # The bare base domain may be served elsewhere (it is for mtaku3.com).
                NB_PROXY_REQUIRE_SUBDOMAIN = "true";
                NB_PROXY_CERTIFICATE_DIRECTORY = "/certs";
                NB_PROXY_ACME_CERTIFICATES = "true";
                NB_PROXY_ACME_CHALLENGE_TYPE = "tls-alpn-01";
                NB_PROXY_FORWARDED_PROTO = "https";
                NB_PROXY_PROXY_PROTOCOL = "true";
                NB_PROXY_TRUSTED_PROXIES = cfg.traefikAddress;
              }
              // optionalAttrs cfg.proxy.crowdsec {
                NB_PROXY_CROWDSEC_API_URL = "http://netbird-crowdsec:8080";
              };
            # NB_PROXY_TOKEN=nbx_...
            environmentFiles =
              [config.age.secrets."netbird/proxy.env".path]
              # NB_PROXY_CROWDSEC_API_KEY=...
              ++ optional cfg.proxy.crowdsec config.age.secrets."netbird/proxy-crowdsec.env".path;
            volumes = [
              "${cfg.dataDir}/proxy-certs:/certs"
            ];
            ports =
              ["${toString cfg.proxy.wireguardPort}:${toString cfg.proxy.wireguardPort}/udp"]
              ++ l4Ports "tcp" cfg.proxy.tcpPorts
              ++ l4Ports "udp" cfg.proxy.udpPorts;
            networks = [cfg.network];
            dependsOn = ["netbird-server"] ++ optional cfg.proxy.crowdsec "netbird-crowdsec";
          };
        }
        // optionalAttrs (cfg.proxy.enable && cfg.proxy.crowdsec) {
          # LAPI only: no local log acquisition, it serves the community
          # blocklists it syncs from CrowdSec's central API.
          netbird-crowdsec = {
            image = "docker.io/crowdsecurity/crowdsec:${cfg.versions.crowdsec}";
            environment.COLLECTIONS = "crowdsecurity/linux";
            # BOUNCER_KEY_netbird_proxy=... registers the proxy's bouncer.
            environmentFiles = [config.age.secrets."netbird/crowdsec.env".path];
            volumes = [
              "${cfg.dataDir}/crowdsec/config:/etc/crowdsec"
              "${cfg.dataDir}/crowdsec/data:/var/lib/crowdsec/data"
            ];
            networks = [cfg.network];
          };
        };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 root root -"
      "d ${cfg.dataDir}/data 0700 root root -"
      "d ${cfg.dataDir}/letsencrypt 0700 root root -"
      "d ${cfg.dataDir}/proxy-certs 0750 ${toString proxyUid} ${toString proxyUid} -"
    ];

    networking.firewall = {
      allowedTCPPorts = [80 443] ++ optionals cfg.proxy.enable cfg.proxy.tcpPorts;
      allowedUDPPorts =
        [cfg.stunPort]
        ++ optionals cfg.proxy.enable ([cfg.proxy.wireguardPort] ++ cfg.proxy.udpPorts);
    };

    capybara.impermanence.directories = [cfg.dataDir];
  };
}
