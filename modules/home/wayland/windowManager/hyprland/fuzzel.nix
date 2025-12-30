{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; {
  config = {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrains Mono Nerd Font:size=12,Noto Color Emoji:size=12";
          dpi-aware = "no";
          use-bold = "yes";
          prompt = "\"  \"";
          placeholder = "\"\"";
          icon-theme = "Tela-Purple";
          icons-enabled = "yes";
          fields = "name,filename,generic,exec,keywords,comment";
          password-character = "";
          filter-desktop = "no";
          match-mode = "fzf";
          sort-result = "yes";
          match-counter = "yes";
          show-actions = "yes";
          launch-prefix = "${pkgs.app2unit}/bin/app2unit --fuzzel-compat -- ";

          lines = 16;
          width = 40;
          tabs = 2;
          horizontal-pad = 28;
          vertical-pad = 20;
          inner-pad = 10;
          line-height = 21;
        };

        colors = {
          background = "161616ff";
          text = "f2f4f8ff";
          prompt = "f2f4f8ff";
          placeholder = "b6b8bbff";
          input = "f2f4f8ff";
          match = "78a9ffff";
          selection = "343434ff";
          selection-text = "F9FBFEff";
          selection-match = "ff7eb6ff";
          counter = "be95ffff";
          border = "3ddbd9ff";
        };

        border = {
          width = 1;
          radius = 10;
        };

        # dmenu = {
        #   mode = "text";
        #   exit-immediately-if-empty = "no";
        # };

        key-bindings = {
          cancel = "Escape Control+c Control+bracketleft Control+braceleft";
          execute = "Return KP_Enter Control+y";
          execute-or-next = "none";
          execute-input = "Shift+Return Shift+KP_Enter Control+Shift+y";
          cursor-left = "Left Control+h";
          cursor-left-word = "Control+Left";
          cursor-right = "Right Control+l";
          cursor-right-word = "Control+Right";
          cursor-home = "none";
          cursor-end = "none";
          delete-line-backward = "none";
          delete-prev = "BackSpace";
          delete-prev-word = "Control+BackSpace";
          delete-next = "Delete KP_Delete";
          delete-next-word = "Control+Delete Control+KP_Delete";
          prev = "Up Control+p";
          prev-with-wrap = "ISO_Left_Tab";
          prev-page = "Page_Up KP_Page_Up Control+u";
          next = "Down Control+n";
          next-with-wrap = "Tab";
          next-page = "Page_Down KP_Page_Down Control+d";
          clipboard-paste = "Control+v XF86Paste";
          first = "Control+a Home";
          last = "Control+e End";
        };
      };
    };
  };
}
