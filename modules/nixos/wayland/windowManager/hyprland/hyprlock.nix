{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = {
    security.pam.services.hyprlock = {};
  };
}
