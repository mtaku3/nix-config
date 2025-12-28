{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  options.capybara.openssh = {
    keys = mkOption {
      type = types.listOf types.str;
      description = "A list of public keys";
      default = [];
    };
  };
}
