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
  tokenPath = config.age.secrets."openclaw/gateway-token".path;
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

    port = mkOpt port 18789 "Gateway port";
  };

  config = mkIf cfg.enable {
    programs.openclaw = {
      enable = true;

      # nix-openclaw's documented secret path: materialise outside the store,
      # hand OpenClaw the path, and let the gateway wrapper read it at run time.
      # This reaches the gateway only -- the CLI is covered by the wrapper below.
      environment.OPENCLAW_GATEWAY_TOKEN = tokenPath;

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

      config.gateway = {
        mode = "local";

        # "lan" rather than "custom" on a single address: the gateway must also
        # listen on loopback for the CLI. A same-host client dialling the LAN
        # address is rejected by the spoofing guard, since that address is one of
        # the gateway host's own interfaces. Exposure is bounded by the firewall,
        # which opens 18789 to 192.168.10.0/24 only.
        bind = "lan";
        port = cfg.port;

        controlUi.allowedOrigins = [cfg.baseUrl];

        # Shared-secret auth. Trusted-proxy would let tinyauth stand in for this,
        # but the Android app cannot present proxy identity headers, so the token
        # is the only scheme every client speaks. Reaching the Control UI still
        # takes the token *and* a device approval, both of which this token alone
        # does not grant.
        auth = {
          mode = "token";
          token = {
            source = "env";
            provider = "default";
            id = "OPENCLAW_GATEWAY_TOKEN";
          };

          # Throttles failed auth. Note the bucket is per client IP and every
          # internet client looks identical from here: the real address is lost
          # at the NodePort, so openclaw sees the k8s node (192.168.10.102) or
          # the cni gateway (10.1.0.1). That makes this one global bucket, which
          # an attacker can keep tripped to lock the operator out -- hence a
          # short lockout. Guessing a 512-bit token is out of reach at any rate,
          # so this is really about log noise and wasted work, not key strength.
          # exemptLoopback stays at its default so the local CLI is unaffected.
          rateLimit = {
            maxAttempts = 20;
            windowMs = 60000;
            lockoutMs = 60000;
          };
        };
      };
    };

    # The gateway wrapper reads the agenix file at ExecStart. agenix.service is a
    # oneshot with no Before=, so without this they race, and a miss is silent:
    # the wrapper falls back to exporting the path string as the token.
    systemd.user.services.openclaw-gateway.Unit = {
      After = ["agenix.service"];
      Wants = ["agenix.service"];
    };

    # programs.openclaw.environment only reaches the gateway, so the CLI would
    # need --token on every call. Shadow it the way this repo already wraps
    # claude and codex: read the secret, export it, hand off. hiPrio because the
    # name collides with the openclaw package nix-openclaw puts in home.packages.
    home.packages = [
      (hiPrio (pkgs.writeShellApplication {
        name = "openclaw";
        text = ''
          if [[ -r ${tokenPath} ]]; then
            OPENCLAW_GATEWAY_TOKEN=$(cat ${tokenPath})
            export OPENCLAW_GATEWAY_TOKEN
          fi
          exec ${getExe pkgs.openclaw} "$@"
        '';
        meta.mainProgram = "openclaw";
      }))
    ];

    # ~/.openclaw holds the agent SQLite stores, credentials and workspace.
    capybara.impermanence.directories = [
      ".openclaw"
    ];
  };
}
