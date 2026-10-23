{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.docker;
in {
  config = {
    # Persist docker files (rootless mode)
    capybara.impermanence.directories = [
      ".local/share/docker"
    ];
  };
}
