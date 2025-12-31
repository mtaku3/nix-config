{
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [
    ./snacks.nix
    ./blink-cmp.nix
    ./lsp.nix
    ./treesitter.nix
    ./conform.nix
    ./mini-statusline.nix
    ./copilot.nix
    ./claude-code.nix
  ];

  config = {
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    opts = {
      hlsearch = false;
      number = true;
      relativenumber = true;
      mouse = "a";
      clipboard = "unnamedplus";
      breakindent = true;
      undofile = true;
      ignorecase = true;
      smartcase = true;
      signcolumn = "yes";
      updatetime = 250;
      completeopt = ["menuone" "noselect"];
      termguicolors = true;
      wrap = false;
      backup = false;
      exrc = false;
    };

    colorschemes.kanagawa.enable = true;

    keymaps = [
      # -- General --
      {
        mode = ["n" "v"];
        key = "<Space>";
        action = "<Nop>";
        options.silent = true;
      }

      # -- Navigation (Word Wrap) --
      {
        mode = "n";
        key = "k";
        action = "v:count == 0 ? 'gk' : 'k'";
        options = {
          expr = true;
          silent = true;
        };
      }
      {
        mode = "n";
        key = "j";
        action = "v:count == 0 ? 'gj' : 'j'";
        options = {
          expr = true;
          silent = true;
        };
      }

      # -- Diagnostics --
      {
        mode = "n";
        key = "[d";
        action.__raw = "vim.diagnostic.goto_prev";
        options.desc = "Go to previous diagnostic message";
      }
      {
        mode = "n";
        key = "]d";
        action.__raw = "vim.diagnostic.goto_next";
        options.desc = "Go to next diagnostic message";
      }

      # -- Visual Mode Moving --
      {
        mode = "v";
        key = "J";
        action = ":m '>+1<CR>gv=gv";
        options.desc = "Move selected text below";
      }
      {
        mode = "v";
        key = "K";
        action = ":m '<-2<CR>gv=gv";
        options.desc = "Move selected text above";
      }

      # -- Navigation (Centering) --
      {
        mode = "n";
        key = "<C-u>";
        action = "<C-u>zz";
      }
      {
        mode = "n";
        key = "<C-d>";
        action = "<C-d>zz";
      }

      # -- Window Navigation --
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
      }

      # -- Save/Quit --
      {
        mode = "n";
        key = "<leader>w";
        action = ":w!<CR>";
      }
      {
        mode = "n";
        key = "<leader>q";
        action = ":q!<CR>";
      }
    ];

    nixpkgs.config.allowUnfree = true;
  };
}
