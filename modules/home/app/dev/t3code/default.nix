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

  # T3's browser is a chrome-headless-shell that T3 Code downloads into
  # ~/.t3/tools, so it loads its libraries through nix-ld too. The libraries
  # the system gives nix-ld lack a few it needs, which T3 Code is pointed at
  # here instead; `t3 browser setup` would install them with a distro package
  # manager. Chrome's sandbox needs nothing more, as NixOS allows unprivileged
  # user namespaces.
  nixLdLibraryPath = concatStringsSep ":" [
    "/run/current-system/sw/share/nix-ld/lib"
    (makeLibraryPath (with pkgs; [
      at-spi2-core # libatk-1.0, libatk-bridge-2.0, libatspi
      libgbm
      libxkbcommon
    ]))
  ];

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
      export T3CODE_TELEMETRY_ENABLED=false
      export NIX_LD_LIBRARY_PATH=${nixLdLibraryPath}

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

    # The unit is written by `t3 service install` with a fixed environment, so
    # the service gets its settings from a drop-in, which survives rewrites.
    xdg.configFile."systemd/user/t3code.service.d/telemetry.conf".text = ''
      [Service]
      Environment=T3CODE_TELEMETRY_ENABLED=false
    '';
    xdg.configFile."systemd/user/t3code.service.d/browser.conf".text = ''
      [Service]
      Environment=NIX_LD_LIBRARY_PATH=${nixLdLibraryPath}
    '';

    capybara.impermanence.directories = [
      {
        directory = ".t3";
        method = "symlink";
      }
    ];
  };
}
