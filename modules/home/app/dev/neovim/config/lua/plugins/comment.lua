return {
  {
    name = "numToStr/Comment.nvim",
    dir = "@comment_nvim@",
    config = function()
      require("Comment").setup()
    end,
  },
}
