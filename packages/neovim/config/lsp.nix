{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    lsp = {
      servers = {
        # nix
        nixd = {
          enable = true;
          config = {
            cmd = ["nixd"];
            filetypes = ["nix"];
            root_markers = ["flake.nix" ".git"];
          };
        };

        # lua
        lua_ls = {
          enable = true;
          config = {
            cmd = ["lua-language-server"];
            filetypes = ["lua"];
            root_markers = [
              ".emmyrc.json"
              ".luarc.json"
              ".luarc.jsonc"
              ".luacheckrc"
              ".stylua.toml"
              "stylua.toml"
              "selene.toml"
              "selene.yml"
              ".git"
            ];
            settings.Lua = {
              codeLens.enable = true;
              hint = {
                enable = true;
                semicolon = "Disable";
              };
            };
          };
        };
      };

      keymaps = [
        {
          key = "<leader>rn";
          lspBufAction = "rename";
          options.desc = "LSP: Rename";
        }
        {
          key = "<leader>ca";
          lspBufAction = "code_action";
          options.desc = "LSP: Code Action";
        }
        {
          key = "K";
          lspBufAction = "hover";
          options.desc = "LSP: Hover Documentation";
        }
        {
          key = "<C-k>";
          lspBufAction = "signature_help";
          options.desc = "LSP: Signature Documentation";
        }
        {
          key = "gD";
          lspBufAction = "declaration";
          options.desc = "LSP: Goto Declaration";
        }
        {
          key = "<leader>wa";
          lspBufAction = "add_workspace_folder";
          options.desc = "LSP: Workspace Add Folder";
        }
        {
          key = "<leader>wr";
          lspBufAction = "remove_workspace_folder";
          options.desc = "LSP: Workspace Remove Folder";
        }

        {
          key = "<leader>wl";
          action = lib.nixvim.mkRaw "function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end";
          options.desc = "LSP: Workspace List Folders";
        }
      ];
    };
  };
}
