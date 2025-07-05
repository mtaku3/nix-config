{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.gpg;
in {
  options.capybara.app.dev.gpg = {
    enable = mkBoolOpt false "Whether to enable the gpg";
  };

  config = mkIf cfg.enable {
    programs.gpg = enabled;
    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-curses;
    };
    capybara.impermanence.directories = [".gnupg"];
  };
}
