return {
  {
    name = "lukas-reineke/indent-blankline.nvim",
    dir = "@indent_blankline_nvim@",
    main = "ibl",
    config = function()
      require("ibl").setup()
    end,
  },
  {
    name = "Darazaki/indent-o-matic",
    dir = "@indent_o_matic@",
    config = function()
      require("indent-o-matic").setup({
        max_lines = 2048,
        standard_widths = { 2, 4, 8 },

        -- Don't detect 8 spaces indentations inside files without a filetype
        filetype_ = {
          standard_widths = { 2, 4 },
        },
      })
    end,
  },
}
