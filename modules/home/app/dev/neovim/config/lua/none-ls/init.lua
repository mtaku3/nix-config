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

-- Build builtins metatable
local logger = require("null-ls.logger")

local export_tables = {
  diagnostics = {},
  formatting = {},
  code_actions = {},
  hover = {},
  completion = {},
  _test = {},
}

for method, table in pairs(export_tables) do
  setmetatable(table, {
    __index = function(t, k)
      local ok, builtin
      ok, builtin = pcall(require, string.format("null-ls.builtins.%s.%s", method, k))
      if not ok then
        ok, builtin = pcall(require, string.format("none-ls.builtins.%s.%s", method, k))
        if not ok then
          logger:warn(string.format("failed to load builtin %s for method %s; please check your config", k, method))
          return
        end
      end

      rawset(t, k, builtin)
      return builtin
    end,
  })
end

M.builtins = setmetatable(export_tables, {
  __index = function(t, k)
    if not rawget(t, k) then
      logger:warn(string.format("failed to load builtin table for method %s; please check your config", k))
    end

    return rawget(t, k)
  end,
})

M.methods = none_ls.methods

M.formatter = none_ls.formatter
M.generator = none_ls.generator

return M
