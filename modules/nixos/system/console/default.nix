{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.console;
in {
  options.capybara.system.console = with types; {
    enable = mkBoolOpt false "Whether to enable the console";
  };

  config = mkIf cfg.enable {
    console.keyMap = "jp106";
  };
}
