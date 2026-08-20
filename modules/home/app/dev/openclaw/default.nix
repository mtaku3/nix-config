{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.openclaw;
  claudeCode = config.capybara.app.dev.claude-code;
in {
  # First-party packaging from the openclaw org. It owns the gateway's systemd
  # user service, the state dirs, and openclaw.json -- which it materialises as a
  # home.file symlink and pairs with OPENCLAW_NIX_MODE=1, the mode openclaw itself
  # honours to treat the config as immutable rather than renaming over it.
  imports = with inputs; [
    nix-openclaw.homeManagerModules.openclaw
  ];

  options.capybara.app.dev.openclaw = with types; {
    enable = mkBoolOpt false "Whether to enable OpenClaw";

    baseUrl = mkOpt str "https://openclaw.mtaku3.com" "Public origin the Control UI is served from";

    bindHost = mkOpt str "192.168.10.101" "Address the gateway listens on";

    port = mkOpt port 18789 "Gateway port";

    trustedProxies = mkOpt (listOf str) ["192.168.10.102"] ''
      Source addresses (IPs or CIDRs) allowed to present trusted-proxy identity
      headers. Only list proxies you control; anything else is rejected before
      the identity header is read.
    '';

    identity = mkOpt str "me@mtaku3.com" "Only proxy-verified identity allowed to reach the gateway";

    userHeader = mkOpt str "remote-email" "Request header carrying the proxy-verified identity";
  };

  config = mkIf cfg.enable {
    programs.openclaw = {
      enable = true;

      # Visible to the gateway only, never to the user's PATH. The wrapper
      # prepends its own toolchain (node, pnpm, curl, jq, python, ffmpeg, sox,
      # ripgrep) and then falls through to the inherited PATH -- which for a
      # systemd --user service is just systemd's own bin, so anything the agent
      # shells out to has to be listed here.
      runtimePackages =
        (with pkgs; [
          bashInteractive
          git
        ])
        # openclaw can reuse the host's Claude CLI login, but only if it resolves
        # `claude` itself. The wrapper is a real derivation, so it goes on the
        # gateway's PATH like any other package; at run time it execs the
        # installer-managed binary in ~/.local/bin.
        ++ optional claudeCode.enable claudeCode.package;

      # The gateway refuses a non-loopback bind without an auth path. We delegate
      # that to tinyauth in front of the IngressRoute, which hands the verified
      # Google identity down as Remote-Email.
      # nix-openclaw reads a value that is an existing path at run time, so the
      # secret stays out of the store. This is the local-direct fallback upstream
      # prescribes for trusted-proxy deployments: the reverse proxy authenticates
      # browsers, and same-host callers that never pass through it -- the CLI, for
      # approving a pending device -- authenticate with this instead.
      environment.OPENCLAW_GATEWAY_PASSWORD = config.age.secrets."openclaw/gateway-password".path;

      # A SecretRef needs its provider declared first; without this the gateway
      # refuses to boot with SecretProviderResolutionError. The env var itself is
      # populated from the agenix file by the wrapper above, so the value never
      # reaches the store or the config file.
      config.secrets.providers.env = {
        source = "env";
        allowlist = ["OPENCLAW_GATEWAY_PASSWORD"];
      };

      config.gateway = {
        mode = "local";
        # "lan" rather than "custom" on bindHost: the gateway must also listen on
        # loopback for the CLI. A same-host client dialling bindHost is rejected
        # by the spoofing guard, since that address is one of the gateway host's
        # own interfaces. Exposure is bounded by the firewall (18789 is open to
        # 192.168.10.0/24 only) and by trustedProxies.
        bind = "lan";
        port = cfg.port;
        trustedProxies = cfg.trustedProxies;
        controlUi.allowedOrigins = [cfg.baseUrl];
        auth = {
          mode = "trusted-proxy";

          # Local-direct fallback for same-host callers that never pass through
          # the reverse proxy -- notably the CLI, which is how a pending device
          # gets approved. Browsers still authenticate via tinyauth.
          password = {
            source = "env";
            provider = "env";
            id = "OPENCLAW_GATEWAY_PASSWORD";
          };
          trustedProxy = {
            userHeader = cfg.userHeader;
            requiredHeaders = ["x-forwarded-proto" "x-forwarded-host"];
            allowUsers = [cfg.identity];
          };
        };
      };
    };

    capybara.impermanence.directories = [
      ".openclaw"
    ];
  };
}
