local M = {}

local on_attach = function(_, bufnr)
  local nmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end

    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
  end
  local telescope = require("telescope.builtin")

  nmap("<leader>rn", vim.lsp.buf.rename, "Rename")
  nmap("<leader>ca", vim.lsp.buf.code_action, "Code Action")

  nmap("gd", telescope.lsp_definitions, "Goto Definition")
  nmap("gr", telescope.lsp_references, "Goto References")
  nmap("gI", telescope.lsp_implementations, "Goto Implementation")
  nmap("<leader>D", telescope.lsp_type_definitions, "Type Definition")
  nmap("<leader>ds", telescope.lsp_document_symbols, "Document Symbols")
  nmap("<leader>ws", telescope.lsp_dynamic_workspace_symbols, "Workspace Symbols")

  nmap("K", vim.lsp.buf.hover, "Hover Documentation")
  nmap("<C-k>", vim.lsp.buf.signature_help, "Signature Documentation")

  nmap("gD", vim.lsp.buf.declaration, "Goto Declaration")
  nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "Workspace Add Folder")
  nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Workspace Remove Folder")
  nmap("<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, "Workspace List Folders")
end

function M.setup(name, config)
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

  require("lspconfig")[name].setup(
    vim.tbl_extend("error", { capabilities = capabilities, on_attach = on_attach }, config or {})
  )
end

return M
