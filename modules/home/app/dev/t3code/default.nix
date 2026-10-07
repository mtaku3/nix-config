{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.t3code;
  t3Home = "${config.home.homeDirectory}/.t3";
  binDir = "${t3Home}/bin";

  # T3 Code is installed with its own installer rather than pinned in the Nix
  # store, so that `t3 update` and the remote updates offered by the apps keep
  # it current. Its executable is a dynamically linked Node SEA, so it relies
  # on nix-ld. The installer links the active version at ${binDir}/t3, which
  # `t3 update` repoints; the wrapper installs on first use and otherwise just
  # execs that link.
  #
  # The background service is left to `t3 service install`: T3 Code owns
  # t3code.service, and updates rewrite and restart it.
  t3Wrapper = pkgs.writeShellApplication {
    name = "t3";
    runtimeInputs = with pkgs; [coreutils curl findutils gnugrep gnused gnutar gzip];
    text = ''
      export T3CODE_HOME=${t3Home}

      if [[ ! -x ${binDir}/t3 ]]; then
        echo "t3: installing T3 Code (${cfg.channel}) into ${t3Home}" >&2
        curl -fsSL https://t3.codes/install.sh | T3CODE_CHANNEL=${cfg.channel} T3CODE_INSTALL_BIN_DIR=${binDir} sh
      fi

      exec ${binDir}/t3 "$@"
    '';
  };
in {
  options.capybara.app.dev.t3code = with types; {
    enable = mkBoolOpt false "Whether to enable T3 Code";

    # Only the first install follows this; `t3 update` keeps to the channel of
    # the installed version.
    channel = mkOpt (enum ["stable" "nightly"]) "stable" "Release channel T3 Code is first installed from";
  };

  config = mkIf cfg.enable {
    # cloudflared for T3 Connect is left to T3 Code as well: `t3 connect link`
    # installs its pinned version into ~/.t3/tools, while one found on the
    # shell's PATH is not seen by the service, which runs with systemd's PATH.
    home.packages = [t3Wrapper];

    capybara.impermanence.directories = [
      {
        directory = ".t3";
        method = "symlink";
      }
    ];
  };
}
