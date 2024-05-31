local M = {}

local none_ls = require("null-ls")

M.deregister = none_ls.deregister
M.disable = none_ls.disable
M.enable = none_ls.enable
M.get_source = none_ls.get_source
M.get_sources = none_ls.get_sources
M.is_registered = none_ls.is_registered
M.register = none_ls.register
M.register_name = none_ls.register_name
M.reset_sources = none_ls.reset_sources
M.toggle = none_ls.toggle

M.builtins = none_ls.builtins
M.methods = none_ls.methods

M.formatter = none_ls.formatter
M.generator = none_ls.generator

return M
