return {
  {
    name = "rebelot/kanagawa.nvim",
    dir = "@kanagawa_nvim@",
    priority = 1000,
    config = function()
      vim.cmd("colorscheme kanagawa-wave")
    end,
  },
}
