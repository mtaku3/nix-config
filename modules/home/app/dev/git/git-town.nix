{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = {
    home.packages = [pkgs.git-town];
  };
}
