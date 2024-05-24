{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.xmobar;
in {
  options.capybara.app.desktop.xmobar = {
    enable = mkBoolOpt false "Whether to enable the xmobar";
  };

  config = mkIf cfg.enable {
    programs.xmobar = let
      i = pkgs.capybara.xmobar-icons;
    in {
      enable = true;
      extraConfig = ''
        Config { overrideRedirect = False
               , font     = "JetBrainsMono NF 10"
               , bgColor  = "#282727"
               , fgColor  = "#c5c9c5"
               , position = TopSize L 100 18
               , commands = [ Run XMonadLog
                            , Run Cpu ["-t", "<icon=${i}/tb-cpu-2.xpm/> <total>%"] 10
                            , Run Memory ["-t", "<icon=${i}/fa-memory.xpm/> <used>GiB", "-d", "1", "--", "--scale", "1024"] 10
                            , Run Date "%m/%d %H:%M:%S" "date" 10
                            ]
               , sepChar  = "%"
               , alignSep = "}{"
               , template = "<hspace=12/> %XMonadLog% }{ %cpu% | %memory% | %date% <hspace=12/>"
               }
      '';
    };
  };
}
