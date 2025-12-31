local lsp = require("lsp")
local none_ls = require("none-ls")

lsp.setup("nil_ls", {})
lsp.setup("hls", {})
-- lsp.setup("lua_ls", {})

none_ls.register({
  none_ls.builtins.formatting.alejandra,
  {
    name = "ormolu",
    method = none_ls.methods.FORMATTING,
    filetypes = { "haskell" },
    generator = none_ls.formatter({
      command = "ormolu",
      args = { "--no-cabal" },
      to_stdin = true,
    }),
  },
  none_ls.builtins.formatting.stylua,
})
