return {
  {
    name = "nvimtools/none-ls.nvim",
    dir = "@none_ls_nvim@",
    config = function()
      require("null-ls").setup({})
    end,
  },
}
