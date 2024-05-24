return {
  {
    name = "neovim/nvim-lspconfig",
    dir = "@nvim_lspconfig@",
    dependencies = {
      { name = "hrsh7th/nvim-cmp", dir = "@nvim_cmp@" },
      { name = "nvim-telescope/telescope.nvim", dir = "@telescope_nvim@" },
    },
    config = function()
      local opts = {
        servers = {
          lua_ls = {
            settings = {
              Lua = {
                workspace = { checkThirdParty = false },
                telemetry = { enable = false },
              },
            },
          },
          pylsp = {
            settings = {
              plugins = {
                autopep8 = { enabled = false },
                flake8 = { enabled = true },
                yapf = { enabled = false },
              },
            },
          },
          texlab = {},
          tsserver = {},
          grammarly = {
            autostart = false,
            filetypes = { "Markdown", "Text", "tex" },
          },
          solargraph = {},
          tailwindcss = {},
          rust_analyzer = {
            settings = {
              ["rust-analyzer"] = {
                check = {
                  command = "clippy",
                },
              },
            },
          },
        },
      }
      for name, config in pairs(opts.servers) do
        require("plugins.lsp.utils").setup(name, config)
      end
    end,
  },
}
