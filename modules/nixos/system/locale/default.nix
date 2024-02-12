{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.locale;
in {
  options.capybara.system.locale = with types; {
    enable = mkBoolOpt false "Whether to enable the locale";
  };

  config = mkIf cfg.enable {
    i18n = {
      extraLocaleSettings = {
        LC_CTYPE = "ja_JP.UTF-8";
        LC_NUMERIC = "ja_JP.UTF-8";
        LC_TIME = "ja_JP.UTF-8";
        LC_COLLATE = "ja_JP.UTF-8";
        LC_MONETARY = "ja_JP.UTF-8";
        LC_MESSAGES = "en_US.UTF-8";
        LC_PAPER = "ja_JP.UTF-8";
        LC_NAME = "ja_JP.UTF-8";
        LC_ADDRESS = "ja_JP.UTF-8";
        LC_TELEPHONE = "ja_JP.UTF-8";
        LC_MEASUREMENT = "ja_JP.UTF-8";
        LC_IDENTIFICATION = "ja_JP.UTF-8";
      };
      supportedLocales = ["ja_JP.UTF-8/UTF-8" "en_US.UTF-8/UTF-8"];
    };
  };
}
