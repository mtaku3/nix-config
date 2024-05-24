return {
  {
    name = "hrsh7th/nvim-cmp",
    dir = "@nvim_cmp@",
    dependencies = {
      {
        name = "hrsh7th/cmp-nvim-lsp",
        dir = "@cmp_nvim_lsp@",
      },
      {
        name = "saadparwaiz1/cmp_luasnip",
        dir = "@cmp_luasnip@",
        dependencies = {
          name = "L3MON4D3/LuaSnip",
          dir = "@luasnip@",
          config = function()
            require("luasnip.loaders.from_vscode").lazy_load()
            require("luasnip").config.setup({})
          end,
        },
      },
      {
        name = "zbirenbaum/copilot-cmp",
        dir = "@copilot_cmp@",
        dependencies = {
          {
            name = "zbirenbaum/copilot.lua",
            dir = "@copilot_lua@",
            cmd = "Copilot",
            event = "InsertEnter",
            config = function()
              require("copilot").setup({})
            end,
          },
        },
        config = function()
          require("copilot_cmp").setup()
        end,
      },
    },
    lazy = true,
    config = function()
      local has_words_before = function()
        if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
          return false
        end
        local line, col = table.unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
      end

      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        completion = {
          completeopt = "menu,menuone,noinsert",
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.abort()
            else
              cmp.complete()
            end
          end),
          ["<C-y>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif require("luasnip").expand_or_locally_jumpable() then
              require("luasnip").expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif require("luasnip").locally_jumpable(-1) then
              require("luasnip").jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = {
          {
            name = "copilot",
            entry_filter = function()
              return has_words_before()
            end,
          },
          { name = "nvim_lsp" },
          { name = "luasnip" },
        },
      })
    end,
  },
}
