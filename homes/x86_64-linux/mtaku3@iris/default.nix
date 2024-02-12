{lib, ...}:
with lib;
with lib.capybara; {
  capybara = {
    desktop.xmonad = enabled;
  };

  home.stateVersion = "23.11";
}
