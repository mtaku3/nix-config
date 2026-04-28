{lib, ...}:
with lib;
with lib.capybara; {
  imports = [./keyboard.nix];

  config = {
    nix.enable = false;

    homebrew = {
      enable = true;
      casks = [
        "vivaldi"
        "postman"
        "sequel-ace"
        "ukelele"
      ];
    };
    system.primaryUser = "usr0200797";

    capybara = {
      app.dev.docker = enabled;
      system.fonts = enabled;
      windowManager.aerospace = enabled;
    };

    system = {
      defaults = {
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          "com.apple.mouse.tapBehavior" = 1;
        };
        dock.autohide = true;
      };
      keyboard = {
        enableKeyMapping = true;
        swapLeftCtrlAndFn = true;
      };
    };

    system.stateVersion = 5;
  };
}
