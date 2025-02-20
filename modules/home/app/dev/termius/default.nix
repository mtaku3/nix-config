{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.termius;
in {
  options.capybara.app.dev.termius = {
    enable = mkBoolOpt false "Whether to enable the termius";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [termius];
    capybara.impermanence.directories = [
      ".config/Termius"
    ];
  };
}
