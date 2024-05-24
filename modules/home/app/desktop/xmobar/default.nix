{
  lib,
  config,
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
    programs.xmobar = {
      enable = true;
      extraConfig = ''
        Config { overrideRedirect = False
               , font     = "xft:iosevka-9"
               , bgColor  = "#5f5f5f"
               , fgColor  = "#f8f8f2"
               , position = Static { xpos = 0, ypos = 0, width = 1080, height = 40 }
               , commands = [ Run Cpu
                                [ "-L", "3"
                                , "-H", "50"
                                , "--high"  , "red"
                                , "--normal", "green"
                                ] 10
                            , Run Memory ["--template", "Mem: <usedratio>%"] 10
                            , Run Swap [] 1
                            , Run Date "%a %Y-%m-%d <fc=#8be9fd>%H:%M</fc>" "date" 10
                            , Run XMonadLog
                            ]
               , sepChar  = "%"
               , alignSep = "}{"
               , template = "%XMonadLog% }{ %alsa:default:Master% | %cpu% | %memory% * %swap% | %EGPF% | %date% "
               }
      '';
    };
  };
}
