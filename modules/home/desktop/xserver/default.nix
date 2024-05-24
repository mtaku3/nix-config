{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.desktop.xserver;
in {
  options.capybara.desktop.xserver = {
    enable = mkBoolOpt false "Whether to enable the xserver";
    preStart = mkOpt types.lines "" "Script to execute before starting the xserver";
    importedVariables = mkOption {
      type = types.listOf (types.strMatching "[a-zA-Z_][a-zA-Z0-9_]*");
      apply = unique;
      example = ["GDK_PIXBUF_ICON_LOADER"];
      visible = false;
      description = ''
        Environment variables to import into the user systemd
        session. The will be available for use by graphical
        services.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.file.".xinitrc".text = ''
      if [ -z "$HM_XPROFILE_SOURCED" ]; then
        . "${config.home.homeDirectory}/.xprofile"
      fi
      unset HM_XPROFILE_SOURCED

      systemctl --user start hm-graphical-session.target

      ${cfg.preStart}

      session=$1
      case $session in
        ${
        if cfg.windowManager.xmonad.enable
        then "xmonad ) exec $HOME/.xmonad/xmonad-${pkgs.stdenv.hostPlatform.system};;"
        else ""
      }
      esac

      systemctl --user stop graphical-session.target
      systemctl --user stop graphical-session-pre.target

      # Wait until the units actually stop.
      while [ -n "$(systemctl --user --no-legend --state=deactivating list-units)" ]; do
        sleep 0.5
      done

      ${optionalString (cfg.importedVariables != [])
        ("systemctl --user unset-environment "
          + escapeShellArgs cfg.importedVariables)}
    '';

    capybara.desktop.xserver.importedVariables = [
      "DBUS_SESSION_BUS_ADDRESS"
      "DISPLAY"
      "SSH_AUTH_SOCK"
      "XAUTHORITY"
      "XDG_DATA_DIRS"
      "XDG_RUNTIME_DIR"
      "XDG_SESSION_ID"
    ];

    systemd.user = {
      services = mkIf (config.home.keyboard != null) {
        setxkbmap = {
          Unit = {
            Description = "Set up keyboard in X";
            After = ["graphical-session-pre.target"];
            PartOf = ["graphical-session.target"];
          };

          Install = {WantedBy = ["graphical-session.target"];};

          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = with config.home.keyboard; let
              args =
                optional (layout != null) "-layout '${layout}'"
                ++ optional (variant != null) "-variant '${variant}'"
                ++ optional (model != null) "-model '${model}'"
                ++ ["-option ''"]
                ++ map (v: "-option '${v}'") options;
            in "${pkgs.xorg.setxkbmap}/bin/setxkbmap ${toString args}";
          };
        };

        xplugd = {
          Unit = {
            Description = "Rerun setxkbmap.service when I/O is changed";
            After = ["graphical-session-pre.target"];
            PartOf = ["graphical-session.target"];
          };

          Install = {WantedBy = ["graphical-session.target"];};

          Service = {
            Type = "forking";
            ExecStart = let
              script = pkgs.writeShellScript "xplugrc" ''
                case "$1,$3" in
                  keyboard,connected)
                  systemctl --user restart setxkbmap.service
                  ;;
                esac
              '';
            in "${pkgs.xplugd}/bin/xplugd ${script}";
          };
        };
      };

      targets = {
        # A basic graphical session target for Home Manager.
        hm-graphical-session = {
          Unit = {
            Description = "Home Manager X session";
            Requires = ["graphical-session-pre.target"];
            BindsTo = ["graphical-session.target" "tray.target"];
          };
        };

        tray = {
          Unit = {
            Description = "Home Manager System Tray";
            Requires = ["graphical-session-pre.target"];
          };
        };
      };
    };

    home.file.".xprofile".text = ''
      . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"

      if [ -e "$HOME/.profile" ]; then
        . "$HOME/.profile"
      fi

      # If there are any running services from a previous session.
      # Need to run this in xprofile because the NixOS xsession
      # script starts up graphical-session.target.
      systemctl --user stop graphical-session.target graphical-session-pre.target

      ${optionalString (cfg.importedVariables != [])
        ("systemctl --user import-environment "
          + escapeShellArgs cfg.importedVariables)}

      export HM_XPROFILE_SOURCED=1
    '';
  };
}
