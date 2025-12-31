{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    plugins = {
      treesitter = {
        enable = true;
        grammarPackages = pkgs.vimPlugins.nvim-treesitter.allGrammars;

        settings = {
          highlight.enable = true;
          indent.enable = true;

          incremental_selection = {
            enable = true;
            keymaps = {
              init_selection = "<C-space>";
              node_incremental = "<C-space>";
              scope_incremental = "<C-s>";
              node_decremental = "<M-space>";
            };
          };
        };
      };

      treesitter-textobjects = {
        enable = true;

        settings = {
          select = {
            enable = true;
            lookahead = true;
            keymaps = {
              "aa" = "@parameter.outer";
              "ia" = "@parameter.inner";
              "af" = "@function.outer";
              "if" = "@function.inner";
              "ac" = "@class.outer";
              "ic" = "@class.inner";
            };
          };

          move = {
            enable = true;
            set_jumps = true;

            goto_next_start = {
              "]m" = "@function.outer";
              "]]" = "@class.outer";
            };
            goto_next_end = {
              "]M" = "@function.outer";
              "][" = "@class.outer";
            };
            goto_previous_start = {
              "[m" = "@function.outer";
              "[[" = "@class.outer";
            };
            goto_previous_end = {
              "[M" = "@function.outer";
              "[]" = "@class.outer";
            };
          };

          swap = {
            enable = true;
            swap_next = {
              "<leader>x" = "@parameter.inner";
            };
            swap_previous = {
              "<leader>X" = "@parameter.inner";
            };
          };
        };
      };
    };
  };
}
