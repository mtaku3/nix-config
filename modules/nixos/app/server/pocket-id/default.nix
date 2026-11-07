{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.pocket-id;
  nbServer = config.capybara.app.server.netbird-server;
  name = "pocket-id";
  port = 1411;
in {
  options.capybara.app.server.pocket-id = with types; {
    enable = mkBoolOpt false "Whether to enable Pocket ID (passkey-only OIDC provider) in Docker";
    domain = mkOpt str "id.${nbServer.baseDomain}" "Public hostname of Pocket ID; passkeys are bound to it, so it must not change";
    network = mkOpt str nbServer.network "Docker network shared with the edge Traefik";
    # renovate: datasource=docker depName=ghcr.io/pocket-id/pocket-id
    version = mkOpt str "v2.19.2" "Pocket ID image tag";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = nbServer.enable;
        message = "capybara.app.server.pocket-id is published by the netbird-server Traefik, so it must be enabled";
      }
    ];

    # Published by the edge Traefik directly rather than through the NetBird
    # reverse proxy: logging in to NetBird itself will depend on Pocket ID.
    capybara.app.server.netbird-server.httpRoutes.${cfg.domain} = "http://${name}:${toString port}";

    virtualisation.oci-containers = {
      backend = "docker";
      containers.${name} = {
        image = "ghcr.io/pocket-id/pocket-id:${cfg.version}";
        environment = {
          APP_URL = "https://${cfg.domain}";
          # Only the edge Traefik forwards to it.
          TRUST_PROXY = nbServer.traefikAddress;
          ANALYTICS_DISABLED = "true";
        };
        # ENCRYPTION_KEY=... (encrypts the token signing keys in the database)
        environmentFiles = [config.age.secrets."pocket-id/pocket-id.env".path];
        # Named volume: the image seeds /app/data with its own ownership. The
        # SQLite database lives here; /var/lib/docker is persisted.
        volumes = ["${name}-data:/app/data"];
        networks = [cfg.network];
      };
    };

    systemd.services."docker-${name}" = {
      requires = ["docker-network-${cfg.network}.service"];
      after = ["docker-network-${cfg.network}.service"];
    };
  };
}
