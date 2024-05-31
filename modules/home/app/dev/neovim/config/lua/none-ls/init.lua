local M = {}

local none_ls = require("null-ls")

M.register = none_ls.register
M.builtins = none_ls.builtins
M.formatter = none_ls.formatter
M.generator = none_ls.generator

return M
