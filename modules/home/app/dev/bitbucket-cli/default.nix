{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.bitbucket-cli;
in {
  options.capybara.app.dev.bitbucket-cli = {
    enable = mkBoolOpt false "Whether to enable the Bitbucket CLI";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.capybara.gildas-bitbucket-cli];

    capybara.impermanence.directories =
      optional pkgs.stdenv.hostPlatform.isLinux ".config/bitbucket";
  };
}
