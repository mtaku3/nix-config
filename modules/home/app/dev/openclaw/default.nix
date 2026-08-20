{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.openclaw;

  package = pkgs.unstable.openclaw;

  # The gateway refuses to start on a non-loopback bind unless it has a way to
  # authenticate. We delegate that to tinyauth, which sits in front of the
  # IngressRoute and hands the verified Google identity down as Remote-Email.
  #
  # `bind = "custom"` listens on bindHost only -- despite what the docs claim, it
  # does not also bind 127.0.0.1. The local CLI is fine either way: it reads the
  # same config and dials bindHost, which the host can reach on its own address.
  settings = {
    gateway = {
      # Required at startup even though the schema marks it optional: the gateway
      # refuses to start on a config without it ("existing config is missing
      # gateway.mode. Treat this as suspicious or clobbered config."). "local"
      # runs the channels and agent runtime on this host, which is what we want.
      mode = "local";
      bind = "custom";
      customBindHost = cfg.bindHost;
      port = cfg.port;
      trustedProxies = cfg.trustedProxies;
      controlUi.allowedOrigins = [cfg.baseUrl];
      auth = {
        mode = "trusted-proxy";
        # No identityScopes / trustedProxy.deviceAutoApprove: docs.openclaw.ai
        # documents them but 2026.6.33's schema rejects both (gateway.auth and
        # gateway.auth.trustedProxy are additionalProperties: false). Scopes come
        # from the one-time `openclaw devices approve` on helios instead.
        trustedProxy = {
          userHeader = cfg.userHeader;
          requiredHeaders = ["x-forwarded-proto" "x-forwarded-host"];
          allowUsers = [cfg.identity];
        };
      };
    };
  };

  configFile = pkgs.writeText "openclaw.json" (builtins.toJSON settings);
in {
  options.capybara.app.dev.openclaw = with types; {
    enable = mkBoolOpt false "Whether to enable OpenClaw";

    baseUrl = mkOpt str "https://openclaw.mtaku3.com" "Public origin the Control UI is served from";

    bindHost = mkOpt str "192.168.10.101" "Address the gateway listens on besides loopback";

    port = mkOpt port 18789 "Gateway port";

    trustedProxies = mkOpt (listOf str) ["192.168.10.102"] ''
      Source addresses (IPs or CIDRs) allowed to present trusted-proxy identity
      headers. Only list proxies you control; anything else is rejected before
      the identity header is read.
    '';

    identity = mkOpt str "me@mtaku3.com" "Only proxy-verified identity allowed to reach the gateway";

    userHeader = mkOpt str "remote-email" "Request header carrying the proxy-verified identity";

    environmentFile = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        EnvironmentFile for the gateway unit, in dotenv format. Intended for
        agenix-managed model credentials, e.g. ANTHROPIC_API_KEY=...
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [package];

    # openclaw replaces openclaw.json by atomic rename, which would swap out a
    # home.file symlink instead of writing through it, so install a real copy.
    # The file is nix-owned: anything written by `openclaw config set` or
    # `openclaw doctor --fix` is discarded on the next home-manager switch.
    #
    # Resolve the directory first. impermanence links ~/.openclaw into the
    # persistent store but only creates the link's *parent* over there, so on the
    # first switch the link dangles and a plain `mkdir -p ~/.openclaw` dies with
    # EEXIST. readlink -f gives the real path whether the link dangles, is
    # already populated, or does not exist at all.
    home.activation.openclawConfig = config.lib.dag.entryAfter ["linkGeneration"] ''
      openclawDir="$(${pkgs.coreutils}/bin/readlink -f "$HOME/.openclaw")"
      run ${pkgs.coreutils}/bin/mkdir -p "$openclawDir"
      run ${pkgs.coreutils}/bin/install -m 600 ${configFile} "$openclawDir/openclaw.json"
    '';

    systemd.user.services.openclaw-gateway = {
      Unit = {
        Description = "OpenClaw gateway";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };

      Service =
        {
          ExecStart = "${getExe package} gateway";
          Restart = "on-failure";
          RestartSec = 5;

          # A systemd --user service inherits almost nothing: without this the
          # daemon runs with PATH=/…/systemd/bin alone, so every subprocess it
          # spawns (claude, git, the shell) fails to resolve, and
          # `openclaw gateway status` flags the missing PATH. Kept deliberately
          # short -- openclaw wants a minimal PATH, not the login shell's.
          Environment = [
            "PATH=${config.home.profileDirectory}/bin:${config.home.homeDirectory}/.local/bin:/run/current-system/sw/bin"
          ];
        }
        // optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = toString cfg.environmentFile;
        };

      Install.WantedBy = ["default.target"];
    };

    # ~/.openclaw holds the agent SQLite stores. SQLite's advisory locking and
    # bindfs (the impermanence default) do not mix well here, so link instead.
    capybara.impermanence.directories = [
      {
        directory = ".openclaw";
        method = "symlink";
      }
    ];
  };
}
