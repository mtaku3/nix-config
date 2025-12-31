{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    plugins = {
      mini-git.enable = lib.mkDefault true;

      mini-statusline = {
        enable = true;

        settings = {
          content.active = lib.nixvim.mkRaw ''
            function()
              local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
              local git           = MiniStatusline.section_git({ trunc_width = 40 })
              local diff          = MiniStatusline.section_diff({ trunc_width = 75 })
              local diagnostics   = MiniStatusline.section_diagnostics({ trunc_width = 75 })
              local filename      = MiniStatusline.section_filename({ trunc_width = 140 })
              local fileinfo      = MiniStatusline.section_fileinfo({ trunc_width = 120 })
              local location      = MiniStatusline.section_location({ trunc_width = 75 })
              local search        = MiniStatusline.section_searchcount({ trunc_width = 75 })

              local lsp = (function()
                -- Check truncation first to save performance on small screens
                if MiniStatusline.is_truncated(75) then return "" end

                -- Get clients attached to the current buffer (0)
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then return "" end

                local names = {}
                for _, client in ipairs(clients) do
                  table.insert(names, client.name)
                end

                -- Returns icon + names, e.g., " nixd, efm"
                return " " .. table.concat(names, ", ")
              end)()

              local formatter = (function()
                if MiniStatusline.is_truncated(75) then return "" end
                local status, conform = pcall(require, "conform")
                if not status then return "" end

                -- list_formatters(0) gets the formatters available for the current buffer
                local formatters = conform.list_formatters(0)
                if #formatters == 0 then return "" end

                local names = {}
                for _, fmt in ipairs(formatters) do
                  table.insert(names, fmt.name)
                end
                return "󰗈 " .. table.concat(names, ", ")
              end)()

              return MiniStatusline.combine_groups({
                { hl = mode_hl,                  strings = { mode } },
                { hl = 'MiniStatuslineDevinfo',  strings = { git, diff, diagnostics } },
                '%<', -- Mark general truncate point
                { hl = 'MiniStatuslineFilename', strings = { filename } },
                '%=', -- End left alignment
                { hl = 'MiniStatuslineFileinfo', strings = { fileinfo, lsp, formatter } },
                { hl = mode_hl,                  strings = { search, location } },
              })
            end
          '';
        };
      };
    };
  };
}
