return {
  {
    name = "neovim/nvim-lspconfig",
    dir = "@nvim_lspconfig@",
    dependencies = {
      { name = "hrsh7th/nvim-cmp", dir = "@nvim_cmp@" },
      { name = "nvim-telescope/telescope.nvim", dir = "@telescope_nvim@" },
    },
  },
}
