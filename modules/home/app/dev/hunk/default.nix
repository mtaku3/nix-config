{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.hunk;
in {
  options.capybara.app.dev.hunk = {
    enable = mkBoolOpt false "Whether to enable the Hunk diff viewer";
  };

  config = mkIf cfg.enable {
    home.packages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hunk
    ];

    capybara.impermanence.directories = [
      ".config/hunk"
    ];
  };
}
