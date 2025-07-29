{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.xplugd;
in {
  options.capybara.app.desktop.xplugd = {
    enable = mkBoolOpt false "Whether to enable the xplugd";
  };

  config = mkIf cfg.enable {
    systemd.user = {
      services = {
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
              homeKeyboardArgs = with config.home.keyboard;
                optional (layout != null) "-layout '${layout}'"
                ++ optional (variant != null) "-variant '${variant}'"
                ++ optional (model != null) "-model '${model}'"
                ++ ["-option ''"]
                ++ map (v: "-option '${v}'") options;

              script = pkgs.writeShellScript "xplugrc" ''
                if [ "$1" != "display" ]; then
                  case "$1,$3,$4" in
                    pointer,connected,"Compx SCYROX 8K Dongle")
                      xinput set-prop $2 'libinput Accel Speed' -0.8
                      ;;
                    keyboard,connected,"M.M Studio JW68")
                      setxkbmap -layout us
                      ;;
                    keyboard,connected,"xrdpKeyboard")
                      setxkbmap -layout us
                      ;;
                    keyboard,connected,*)
                      setxkbmap ${toString homeKeyboardArgs}
                      ;;
                  esac
                  exit 0
                fi
              '';
            in "${pkgs.xplugd}/bin/xplugd ${script}";
          };
        };
      };
    };
  };
}
