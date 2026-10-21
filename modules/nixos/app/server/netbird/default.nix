{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.server.netbird;
  setupKey = "netbird/setup-key";
in {
  options.capybara.app.server.netbird = with types; {
    enable = mkBoolOpt false "Whether to enable the netbird";
    managementUrl = mkOpt str "https://netbird.mtaku3.com" "Management server the client registers with";
    autoLogin = mkOpt bool (config.age.secrets ? ${setupKey}) "Whether to log in with the ${setupKey} agenix secret when the client needs login (on by default once the host has one)";
    routing = mkOpt (enum ["none" "client" "server" "both"]) "none" "Kernel settings for NetBird routing (see services.netbird.useRoutingFeatures)";
    users = mkOpt (listOf str) ["mtaku3"] "Users allowed to drive the daemon (netbird-wt0 status/up) without sudo";
  };

  config = mkIf cfg.enable {
    services.netbird = {
      # Match the self-hosted server version; nixpkgs lags behind it.
      package = pkgs.unstable.netbird.overrideAttrs (finalAttrs: _: {
        version = "0.81.3";
        src = pkgs.fetchFromGitHub {
          owner = "netbirdio";
          repo = "netbird";
          tag = "v${finalAttrs.version}";
          hash = "sha256-MGlUFuF11CQClB5kmJ4TTLpO3rwuCeNmjgKfOUxVvE8=";
        };
        vendorHash = "sha256-e6gG99OhfYcygQIqKyC9M4TajbH/6+L/IoMa3lzoq5k=";
        # Only the UI build uses the frontend dependencies.
        pnpmDeps = null;
      });
      useRoutingFeatures = cfg.routing;

      clients.wt0 = {
        # Port used to listen to wireguard connections
        port = 51821;

        # Set this to true if you want the GUI client
        ui.enable = false;

        # This opens ports required for direct connection without a relay
        openFirewall = true;

        # This opens necessary firewall ports in the Netbird client's network interface
        openInternalFirewall = true;

        # Picked up by `netbird up`, including the login unit below.
        environment.NB_MANAGEMENT_URL = cfg.managementUrl;
        # The daemon itself reads the URL from config.json, which may still
        # point at NetBird Cloud from an earlier login; pin it so the peer
        # moves over (and logs in again with the setup key).
        config.ManagementURL = {
          Scheme = "https";
          Host = "${removePrefix "https://" cfg.managementUrl}:443";
          Path = "";
        };

        login = mkIf cfg.autoLogin {
          enable = true;
          setupKeyFile = config.age.secrets.${setupKey}.path;
        };
      };
    };

    # The upstream login script waits for `status` to match 'Connected', which
    # "Management: Disconnected" also matches, so it checks for NeedsLogin
    # before the daemon's first login attempt and never logs in.
    systemd.services.netbird-wt0-login.script = mkIf cfg.autoLogin (mkForce ''
      netbird=${getExe config.services.netbird.clients.wt0.wrapper}
      for _ in $(seq 120); do
        status=$("$netbird" status 2>&1 || :)
        if grep -q 'NeedsLogin' <<<"$status"; then
          exec "$netbird" up --setup-key-file="$NB_SETUP_KEY_FILE"
        fi
        if grep -q 'Management: Connected' <<<"$status"; then
          exit 0
        fi
        sleep 1
      done
      echo "NetBird neither connected nor asked for login in time" >&2
      exit 1
    '');

    # The hardened daemon's socket is group-owned by its service user.
    users.users = genAttrs cfg.users (_: {
      extraGroups = [config.services.netbird.clients.wt0.user.group];
    });

    capybara.impermanence.directories = [
      "/var/lib/netbird-wt0"
    ];
  };
}
