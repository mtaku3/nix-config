{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; {
  config = {
    capybara = {
      suites.common = enabled;

      app.server.ssh = enabled;
    };
  };
}
