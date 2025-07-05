return {
  {
    name = "frabjous/knap",
    dir = "@knap@",
    ft = { "tex", "plaintex", "bib" },
    config = function()
      -- TODO: Temporarily tex output directory defaults to PDF/, but should be detected from latexmkrc
      vim.g.knap_settings = {
        textopdf = "latexmk %srcfile%",
        textopdfviewerlaunch = "okular --unique PDF/%outputfile%",
        textopdfviewerrefresh = "none",
        textopdfforwardjump = "okular --unique PDF/%outputfile%'#src:%line '%srcfile%",
      }

      vim.keymap.set("n", "<leader>p", function()
        require("knap").toggle_autopreviewing()
      end)
    end,
  },
}
