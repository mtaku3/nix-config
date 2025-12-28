{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.pycharm;
in {
  options.capybara.app.dev.pycharm = {
    enable = mkBoolOpt false "Whether to enable the pycharm";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [jetbrains.pycharm];
    capybara.impermanence.directories = [".config/JetBrains"];
  };
}
