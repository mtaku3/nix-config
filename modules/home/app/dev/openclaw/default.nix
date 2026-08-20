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
      runtimePackages = with pkgs; [
        bashInteractive
        git
      ];

      # The gateway refuses a non-loopback bind without an auth path. We delegate
      # that to tinyauth in front of the IngressRoute, which hands the verified
      # Google identity down as Remote-Email.
      config.gateway = {
        mode = "local";
        bind = "custom";
        customBindHost = cfg.bindHost;
        port = cfg.port;
        trustedProxies = cfg.trustedProxies;
        controlUi.allowedOrigins = [cfg.baseUrl];
        auth = {
          mode = "trusted-proxy";
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
