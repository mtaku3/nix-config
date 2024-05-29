{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.gh;
in {
  options.capybara.app.dev.gh = {
    enable = mkBoolOpt false "Whether to enable the github cli";
  };

  config = mkIf cfg.enable {
    programs.gh = enabled;
    capybara.impermanence.files = [".config/gh/hosts.yml"];
  };
}
