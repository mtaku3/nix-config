{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.neovim;
in {
  options.capybara.app.dev.neovim = {
    enable = mkBoolOpt false "Whether to enable the neovim";
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.capybara.neovim];

    capybara.impermanence.directories = [
      ".config/github-copilot"
    ];
  };
}
