{
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [
    (lib.nixvim.plugins.mkNeovimPlugin {
      name = "claudecode";
      package = "claudecode-nvim";
      maintainers = [];
    })
  ];

  config = {
    plugins.claudecode = {
      enable = true;

      settings = {
        terminal.snacks_win_opts = {
          min_width = 40;

          keys = {
            hide =
              (lib.nixvim.listToUnkeyedAttrs [
                "<C-g>"
                (lib.nixvim.mkRaw ''
                  function(self)
                    self:hide()
                  end
                '')
              ])
              // {
                mode = "t";
                desc = "Hide";
              };
            navigate-left =
              (lib.nixvim.listToUnkeyedAttrs [
                "<C-h>"
                (lib.nixvim.mkRaw ''
                  function()
                    vim.cmd.wincmd("h")
                  end
                '')
              ])
              // {
                mode = "t";
                desc = "Navigate left";
              };

            navigate-down =
              (lib.nixvim.listToUnkeyedAttrs [
                "<C-j>"
                (lib.nixvim.mkRaw ''
                  function()
                    vim.cmd.wincmd("j")
                  end
                '')
              ])
              // {
                mode = "t";
                desc = "Navigate down";
              };

            navigate-up =
              (lib.nixvim.listToUnkeyedAttrs [
                "<C-k>"
                (lib.nixvim.mkRaw ''
                  function()
                    vim.cmd.wincmd("k")
                  end
                '')
              ])
              // {
                mode = "t";
                desc = "Navigate up";
              };

            navigate-right =
              (lib.nixvim.listToUnkeyedAttrs [
                "<C-l>"
                (lib.nixvim.mkRaw ''
                  function()
                    vim.cmd.wincmd("l")
                  end
                '')
              ])
              // {
                mode = "t";
                desc = "Navigate right";
              };
          };
        };
      };
    };

    keymaps = [
      # Toggle / Focus
      {
        mode = "n";
        key = "<C-g>";
        action = "<cmd>ClaudeCodeFocus<cr>";
        options.desc = "Focus Claude";
      }

      # Session Management
      {
        mode = "n";
        key = "<leader>ar";
        action = "<cmd>ClaudeCode --resume<cr>";
        options.desc = "Resume Claude";
      }
      {
        mode = "n";
        key = "<leader>aC";
        action = "<cmd>ClaudeCode --continue<cr>";
        options.desc = "Continue Claude";
      }

      # Tools
      {
        mode = "n";
        key = "<leader>ab";
        action = "<cmd>ClaudeCodeAdd %<cr>";
        options.desc = "Add current buffer";
      }

      # Visual Mode Send
      {
        mode = "v";
        key = "<leader>as";
        action = "<cmd>ClaudeCodeSend<cr>";
        options.desc = "Send to Claude";
      }

      # Diff Management
      {
        mode = "n";
        key = "<leader>aa";
        action = "<cmd>ClaudeCodeDiffAccept<cr>";
        options.desc = "Accept diff";
      }
      {
        mode = "n";
        key = "<leader>ad";
        action = "<cmd>ClaudeCodeDiffDeny<cr>";
        options.desc = "Deny diff";
      }
    ];

    autoCmd = [
      {
        event = "FileType";
        pattern = ["NvimTree" "neo-tree" "oil" "minifiles" "netrw"];
        callback = ''
          function()
            vim.keymap.set("n", "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", {
              buffer = true,
              desc = "Add file to Claude",
              silent = true
            })
          end
        '';
      }
    ];
  };
}
