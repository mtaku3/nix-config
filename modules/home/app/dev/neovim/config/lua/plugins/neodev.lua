return {
  {
    name = "folke/neodev.nvim",
    dir = "@neodev_nvim@",
    dependencies = { name = "hrsh7th/nvim-cmp", dir = "@nvim_cmp@" },
    config = function()
      require("neodev").setup({})
    end,
  },
}
