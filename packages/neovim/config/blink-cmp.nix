{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    plugins.blink-cmp = {
      enable = true;

      settings = {
        keymap = {
          "<Tab>" = ["select_next" "snippet_forward" "fallback"];
          "<S-Tab>" = ["select_prev" "snippet_backward" "fallback"];

          "<C-p>" = ["select_prev" "fallback"];
          "<C-n>" = ["select_next" "fallback"];

          "<C-u>" = ["scroll_documentation_up" "fallback"];
          "<C-d>" = ["scroll_documentation_down" "fallback"];

          "<C-y>" = ["select_and_accept"];
        };

        appearance = {
          use_nvim_cmp_as_default = true;
          nerd_font_variant = "mono";
        };
      };
    };
  };
}
