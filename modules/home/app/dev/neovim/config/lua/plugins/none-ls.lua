return {
  {
    name = "nvimtools/none-ls.nvim",
    dir = "@none_ls_nvim@",
    config = function()
      require("null-ls").setup({
        on_attach = function(_, bufnr)
          vim.keymap.set("n", "<leader>f", function()
            vim.lsp.buf.format({ name = "null-ls", timeout_ms = 10000 })
          end, { buffer = bufnr, desc = "none-ls: Format current buffer with none-ls" })
        end
      })
    end,
  },
}
