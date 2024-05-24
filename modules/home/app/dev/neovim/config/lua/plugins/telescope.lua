return {
  {
    name = "nvim-telescope/telescope.nvim",
    dir = "@telescope_nvim@",
    dependencies = {
      { name = "nvim-lua/plenary.nvim", dir = "@plenary_nvim@" },
      {
        name = "nvim-telescope/telescope-fzf-native.nvim",
        dir = "@telescope_fzf_native_nvim@",
        -- build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
      },
    },
    config = function()
      local telescope = require("telescope")

      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
        },
      })

      pcall(telescope.load_extension, "fzf")

      vim.keymap.set("n", "<leader>?", require("telescope.builtin").oldfiles, { desc = "Find recently opened files" })
      vim.keymap.set("n", "<leader><space>", require("telescope.builtin").buffers, { desc = "Find existing buffers" })
      vim.keymap.set("n", "<leader>/", function()
        require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
          winblend = 10,
          previewer = false,
        }))
      end, { desc = "Fuzzily search in current buffer" })

      vim.keymap.set("n", "<leader>gf", require("telescope.builtin").git_files, { desc = "Search git files" })
      vim.keymap.set("n", "<leader>sf", require("telescope.builtin").find_files, { desc = "Search files" })
      vim.keymap.set("n", "<leader>sw", require("telescope.builtin").grep_string, { desc = "Search current word" })
      vim.keymap.set("n", "<leader>sh", require("telescope.builtin").help_tags, { desc = "Search help" })
      vim.keymap.set("n", "<leader>sg", require("telescope.builtin").live_grep, { desc = "Search by grep" })
    end,
  },
}
