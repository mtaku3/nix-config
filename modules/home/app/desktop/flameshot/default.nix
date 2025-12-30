{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.flameshot;
in {
  options.capybara.app.desktop.flameshot = {
    enable = mkBoolOpt false "Whether to enable the flameshot";
  };

  config = mkIf cfg.enable {
    services.flameshot = {
      enable = true;

      settings = {
        General = {
          uiColor = "#658594";
          disabledTrayIcon = true;

          # savePath = "/tmp";
          # saveAsFileExtension = ".png";
          # showHelp = true;
          # showSidePanelButton = true;
          # showDesktopNotification = true;
          # filenamePattern = "%F_%H-%M";
          # allowMultipleGuiInstances = false;
          # startupLaunch = true;
          # contrastOpacity = 190;
        };

        Shortcuts = {
          # TYPE_COPY = "Ctrl+C";
          # TYPE_SAVE = "Ctrl+S";
          # TYPE_EXIT = "Ctrl+Q";
        };
      };
    };
  };
}
