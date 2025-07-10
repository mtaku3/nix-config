{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.minio-cli;
in {
  options.capybara.app.dev.minio-cli = {
    enable = mkBoolOpt false "Whether to enable the minio-cli";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [minio-client];

    capybara.impermanence.directories = [
      ".mc"
    ];
  };
}
