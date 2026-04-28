{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
{
  config = let
    package = pkgs.autoraise;
  in {
    environment.systemPackages = [package];

    launchd.user.agents.autoraise.serviceConfig = {
      ProgramArguments = ["${package}/bin/autoraise" "-disableKey" "disabled"];
      KeepAlive = true;
      RunAtLoad = true;
    };
  };
}
