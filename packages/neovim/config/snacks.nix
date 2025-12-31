{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    plugins.snacks = {
      enable = true;

      settings = {
        picker.sources.explorer = {
          auto_close = true;
          layout = {
            preset = "ivy";
            fullscreen = true;
            hidden = ["input"];
          };
        };
        explorer.replace_netrw = true;
        indent.enabled = true;
        notifier.enabled = true;
      };
    };

    keymaps = [
      # -- Explorer --
      {
        key = "<leader>e";
        action = lib.nixvim.mkRaw "function() Snacks.explorer() end";
        options.desc = "File Explorer";
      }

      # -- Picker --
      {
        key = "<leader><space>";
        action = lib.nixvim.mkRaw "function() Snacks.picker.buffers() end";
        options.desc = "Buffers";
      }
      {
        key = "<leader>/";
        action = lib.nixvim.mkRaw "function() Snacks.picker.grep() end";
        options.desc = "Grep";
      }
      {
        key = "<leader>n";
        action = lib.nixvim.mkRaw "function() Snacks.picker.notifications() end";
        options.desc = "Notification History";
      }
      {
        key = "<leader>gf";
        action = lib.nixvim.mkRaw "function() Snacks.picker.git_files() end";
        options.desc = "Search git files";
      }
      {
        key = "<leader>sf";
        action = lib.nixvim.mkRaw "function() Snacks.picker.files() end";
        options.desc = "Search files";
      }
      {
        mode = ["n" "x"];
        key = "<leader>sw";
        action = lib.nixvim.mkRaw "function() Snacks.picker.grep_word() end";
        options.desc = "Search current word";
      }
      {
        key = "<leader>sg";
        action = lib.nixvim.mkRaw "function() Snacks.picker.grep() end";
        options.desc = "Search by grep";
      }
      {
        key = "<leader>gs";
        action = lib.nixvim.mkRaw "function() Snacks.picker.git_status() end";
        options.desc = "Search git Status";
      }
      {
        key = "gd";
        action = lib.nixvim.mkRaw "function() Snacks.picker.lsp_definitions() end";
        options.desc = "LSP: Goto Definition";
      }
      {
        key = "gr";
        action = lib.nixvim.mkRaw "function() Snacks.picker.lsp_references() end";
        options = {
          nowait = true;
          desc = "LSP: Goto References";
        };
      }
      {
        key = "gI";
        action = lib.nixvim.mkRaw "function() Snacks.picker.lsp_implementations() end";
        options.desc = "LSP: Goto Implementation";
      }
      {
        key = "<leader>D";
        action = lib.nixvim.mkRaw "function() Snacks.picker.lsp_type_definitions() end";
        options.desc = "LSP: Goto Type Definition";
      }
      {
        key = "<leader>ds";
        action = lib.nixvim.mkRaw "function() Snacks.picker.lsp_symbols() end";
        options.desc = "LSP: Document Symbols";
      }
      {
        key = "<leader>ws";
        action = lib.nixvim.mkRaw "function() Snacks.picker.lsp_workspace_symbols() end";
        options.desc = "LSP: Workspace Symbols";
      }

      # -- gh --
      {
        mode = "n";
        key = "<leader>gi";
        action = lib.nixvim.mkRaw "function() Snacks.picker.gh_issue() end";
        options.desc = "GitHub Issues (open)";
      }
      {
        mode = "n";
        key = "<leader>gI";
        action = lib.nixvim.mkRaw "function() Snacks.picker.gh_issue({ state = 'all' }) end";
        options.desc = "GitHub Issues (all)";
      }
      {
        mode = "n";
        key = "<leader>gp";
        action = lib.nixvim.mkRaw "function() Snacks.picker.gh_pr() end";
        options.desc = "GitHub Pull Requests (open)";
      }
      {
        mode = "n";
        key = "<leader>gP";
        action = lib.nixvim.mkRaw "function() Snacks.picker.gh_pr({ state = 'all' }) end";
        options.desc = "GitHub Pull Requests (all)";
      }
    ];

    extraPackages = with pkgs; [
      ripgrep
      fd
    ];
  };
}
