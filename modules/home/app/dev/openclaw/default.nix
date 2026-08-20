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
      # nix-openclaw's documented secret path: materialise outside the store,
      # hand OpenClaw the path, and let the gateway wrapper read it at run time.
      # This reaches the gateway only -- the CLI is covered by the wrapper below.
      environment.OPENCLAW_GATEWAY_PASSWORD = config.age.secrets."openclaw/gateway-password".path;

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
            provider = "default";
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

    # The gateway wrapper reads the agenix file at ExecStart. agenix.service is a
    # oneshot with no Before=, so without this they race, and a miss is silent:
    # the wrapper falls back to exporting the path string as the password.
    systemd.user.services.openclaw-gateway.Unit = {
      After = ["agenix.service"];
      Wants = ["agenix.service"];
    };

    # programs.openclaw.environment only reaches the gateway, so the CLI would
    # need --password on every call. Shadow it the way this repo already wraps
    # claude and codex: read the secret, export it, hand off. hiPrio because the
    # name collides with the openclaw package nix-openclaw puts in home.packages.
    home.packages = [
      (hiPrio (pkgs.writeShellApplication {
        name = "openclaw";
        text = ''
          if [[ -r ${config.age.secrets."openclaw/gateway-password".path} ]]; then
            OPENCLAW_GATEWAY_PASSWORD=$(cat ${config.age.secrets."openclaw/gateway-password".path})
            export OPENCLAW_GATEWAY_PASSWORD
          fi
          exec ${getExe pkgs.openclaw} "$@"
        '';
        meta.mainProgram = "openclaw";
      }))
    ];

    capybara.impermanence.directories = [
      ".openclaw"
    ];
  };
}
