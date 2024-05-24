return {
  {
    name = "nvim-neo-tree/neo-tree.nvim",
    dir = "@neo_tree_nvim@",
    dependencies = {
      { name = "nvim-lua/plenary.nvim", dir = "@plenary_nvim@" },
      { name = "nvim-tree/nvim-web-devicons", dir = "@nvim_web_devicons@" },
      { name = "MunifTanjim/nui.nvim", dir = "@nui_nvim@" },
    },
    config = function()
      require("neo-tree").setup({
        use_default_mappings = false,
        window = {
          position = "current",
          mapping_options = {
            noremap = true,
            nowait = true,
          },
          mappings = {
            -- ["<leader>"] = {
            -- 	"toggle_node",
            -- 	nowait = true,
            -- },
            ["<CR>"] = "open",
            -- ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
            ["a"] = {
              "add",
              config = {
                show_path = "none",
              },
            },
            ["A"] = "add_directory",
            ["d"] = "delete",
            ["r"] = "rename",
            ["c"] = "copy",
            ["m"] = "move",
            ["q"] = "close_window",
          },
        },
      })
      vim.keymap.set("n", "<leader>e", ":Neotree reveal<CR>", { desc = "Toggle file explorer" })
    end,
  },
}
