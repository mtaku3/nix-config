{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.nix.devenv-cachix;
in {
  options.capybara.nix.devenv-cachix = with types; {
    enable = mkBoolOpt false "Whether to enable the devenv-cachix";
  };

  config = mkIf cfg.enable {
    nix.settings = {
      trusted-substituters = [
        "https://devenv.cachix.org"
      ];
      trusted-public-keys = [
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];
    };
  };
}
