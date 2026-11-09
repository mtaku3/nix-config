{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.grok;

  grokWrapper = pkgs.writeShellApplication {
    name = "grok";
    # No runtimeInputs: the wrapper deliberately calls the user's
    # installer-managed binary at ~/.local/bin/grok by absolute path, and only
    # uses bash builtins + `cat` for the missing-install message.
    text = ''
      REAL=$HOME/.local/bin/grok

      if [[ ! -x $REAL ]]; then
        cat >&2 <<'EOF'
      grok is not installed.

      Install into ~/.local (self-updates via npm):
        npm install -g @xai-official/grok --prefix "$HOME/.local"

      Then sign in with your SuperGrok / X Premium+ subscription:
        grok login                # browser on this machine
        grok login --device-auth  # SSH / remote

      Docs: https://docs.x.ai/build
      EOF
        exit 127
      fi

      exec "$REAL" "$@"
    '';
    meta = {
      description = "Wrapper around the installer-managed Grok Build CLI";
      mainProgram = "grok";
    };
  };
in {
  options.capybara.app.dev.grok = {
    enable = mkBoolOpt false "Whether to enable the Grok Build CLI";
  };

  config = mkIf cfg.enable {
    # grok is installed by hand into ~/.local/bin/grok (via
    # `npm install -g @xai-official/grok --prefix ~/.local`) rather than taken
    # from nixpkgs, whose grok-build lags far behind upstream. The npm
    # bootstrap unpacks the native binary into ~/.grok/bin, which is
    # dynamically linked and so relies on nix-ld on NixOS.
    home.packages = [grokWrapper];

    # ~/.grok holds config.toml, auth.json (subscription OAuth token), sessions
    # and the unpacked binaries.
    capybara.impermanence.directories = [
      ".grok"
    ];
  };
}
