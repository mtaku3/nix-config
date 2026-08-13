{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.paseo;
in {
  options.capybara.app.dev.paseo = {
    enable = mkBoolOpt false "Whether to enable Paseo";

    appBaseUrl = mkOpt types.str "https://paseo.mtaku3.com" "Paseo web app base URL";

    relayEndpoint = mkOpt types.str "relay.paseo.mtaku3.com:443" "Paseo relay endpoint";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.capybara.paseo
    ];

    home.file.".paseo/config.json".text = builtins.toJSON {
      "$schema" = "https://paseo.sh/schemas/paseo.config.v1.json";
      version = 1;
      app.baseUrl = cfg.appBaseUrl;
      daemon = {
        cors.allowedOrigins = [cfg.appBaseUrl];
        relay = {
          enabled = true;
          endpoint = cfg.relayEndpoint;
          publicEndpoint = cfg.relayEndpoint;
          useTls = true;
          publicUseTls = true;
        };
      };
    };

    capybara.impermanence.directories = [
      ".paseo"
    ];
  };
}
