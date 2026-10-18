{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.claude-swap;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
in {
  options.capybara.app.dev.claude-swap = {
    enable = mkBoolOpt false "Whether to enable claude-swap (cswap), the Claude Code account switcher";
    autoSwitch = mkBoolOpt false "Whether to run `cswap auto --once` every 5 minutes, configured through `cswap config set autoswitch.*`";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home.packages = [pkgs.capybara.claude-swap];

      # cswap keeps each account's backed-up credentials here on Linux; macOS
      # stores them in the Keychain and ~/.claude-swap-backup instead.
      capybara.impermanence.directories = optionals isLinux [
        ".local/share/claude-swap"
      ];
    }

    # The systemd form of the cron job the cswap README suggests:
    #   */5 * * * * cswap auto --once --json
    # cswap swaps the default login in ~/.claude, which every claude process
    # re-reads on its next message -- including the ones T3 Code spawns.
    (mkIf (cfg.autoSwitch && isLinux) {
      systemd.user.services.cswap-auto = {
        Unit.Description = "Switch Claude Code accounts before they hit their rate limit";
        Service = {
          Type = "oneshot";
          ExecStart = "${getExe pkgs.capybara.claude-swap} auto --once --json";
          # 2 = nothing to do, 3 = no viable target; neither is a failure.
          SuccessExitStatus = "2 3";
        };
      };

      systemd.user.timers.cswap-auto = {
        Unit.Description = "Run cswap auto every 5 minutes";
        Timer.OnCalendar = "*:0/5";
        Install.WantedBy = ["timers.target"];
      };
    })
  ]);
}
