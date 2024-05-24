return {
  {
    name = "rcarriga/nvim-notify",
    dir = "@nvim_notify@",
    config = function()
      require("notify").setup()
      vim.notify = require("notify")
    end,
  },
}
