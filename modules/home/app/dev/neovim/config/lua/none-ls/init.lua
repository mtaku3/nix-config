local M = {}

local null_ls = require("null-ls")
local default_settings = {
	sources = {
		null_ls.builtins.formatting.stylua,

		null_ls.builtins.formatting.isort,
		null_ls.builtins.formatting.black,

		null_ls.builtins.formatting.rustfmt,

		null_ls.builtins.code_actions.eslint_d,
		null_ls.builtins.diagnostics.eslint_d,

		null_ls.builtins.formatting.eslint_d,
		null_ls.builtins.formatting.prettierd,

		null_ls.builtins.diagnostics.rubocop,
		null_ls.builtins.formatting.rubocop,
	},
}

function M.setup(user_settings)
	local settings = vim.tbl_deep_extend("keep", user_settings or {}, default_settings)
	require("null-ls").setup(settings)
end

return M
