{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  options.capybara.shell = {
    path = mkOption {
      type = types.path;
      description = "Path to bourne shell";
    };
  };
}
