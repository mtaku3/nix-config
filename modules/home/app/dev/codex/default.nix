{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.codex;

  # Final exec of the wrapper. In agmsg monitor mode we hand off to the agmsg
  # codex shim, which enables agmsg's app-server bridge only for interactive
  # launches in projects whose codex delivery mode is `monitor` and passes
  # everything else straight through. AGMSG_REAL_CODEX pins the installer-managed
  # binary so the shim (and codex-monitor.sh, which reads
  # ''${AGMSG_REAL_CODEX:-codex}) resolves it directly instead of rediscovering
  # this wrapper on PATH and recursing. Falls back to the real binary when the
  # shim is not installed, so codex keeps working before agmsg is set up.
  launch =
    if cfg.agmsgMonitor
    then ''
      SHIM=$HOME/.agents/skills/agmsg/scripts/drivers/types/codex/codex-shim.sh
      if [[ -x $SHIM ]]; then
        export AGMSG_REAL_CODEX=$REAL
        exec "$SHIM" "$@"
      fi
      exec "$REAL" "$@"
    ''
    else ''exec "$REAL" "$@"'';

  codexWrapper = pkgs.writeShellApplication {
    name = "codex";
    # No runtimeInputs: the wrapper deliberately calls the user's
    # installer-managed binary at ~/.local/bin/codex by absolute path,
    # and only uses bash builtins + `cat` (provided by writeShellApplication's
    # default PATH) for the missing-install message.
    text = ''
      REAL=$HOME/.local/bin/codex

      if [[ ! -x $REAL ]]; then
        cat >&2 <<'EOF'
      codex is not installed.

      Install into ~/.local (self-updates via npm):
        npm install -g @openai/codex --prefix "$HOME/.local"

      Docs: https://developers.openai.com/codex/cli
      EOF
        exit 127
      fi

      ${cfg.preStart}

      ${launch}
    '';
    meta = {
      description = "Wrapper around the installer-managed codex binary";
      mainProgram = "codex";
    };
  };
in {
  options.capybara.app.dev.codex = {
    enable = mkBoolOpt false "Whether to enable codex";

    agmsgMonitor = mkBoolOpt false ''
      Route the codex wrapper through the agmsg monitor shim at
      ~/.agents/skills/agmsg/scripts/drivers/types/codex/codex-shim.sh.

      The shim enables agmsg's app-server bridge only for interactive launches
      in projects whose codex delivery mode is `monitor`, passing every other
      invocation through to the installer-managed binary unchanged. Equivalent
      to the shell function agmsg recommends:

        codex() {
          ~/.agents/skills/agmsg/scripts/drivers/types/codex/codex-shim.sh "$@"
        }

      Falls back to the real binary when the shim is not installed.
    '';

    preStart = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Shell snippet sourced by the codex wrapper before exec'ing the
        installer-managed binary. Intended for exporting secrets read from
        agenix-managed files, e.g.

          export OPENAI_API_KEY=$(cat ''${config.age.secrets.openai.path})

        Runs under `set -euo pipefail`; a non-zero exit aborts the wrapper
        before codex runs.
      '';
    };
  };

  config = mkIf cfg.enable {
    # codex is installed by hand into ~/.local/bin/codex (e.g. via
    # `npm install -g @openai/codex --prefix ~/.local`) so it can self-update.
    # The wrapper below shadows that binary on PATH so we can run preStart
    # hooks (typically secret exports) first. Node and friends are provided by
    # the claude-code module, which is enabled alongside codex on every host
    # that uses it.
    home.packages = [
      codexWrapper
    ];

    capybara.impermanence.directories = [
      ".codex"
    ];
  };
}
