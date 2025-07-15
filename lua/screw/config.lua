--- Configuration management for screw.nvim
---
--- This module handles configuration loading, validation, and default values
--- following Neovim plugin best practices with proper LuaCATS support.
---

-- Import configuration meta types for LSP support
require("screw.config.meta")

local internal_config = require("screw.config.internal")

local M = {}

--- Current internal configuration (no nil values)
---@type screw.InternalConfig
M.options = {}

--- Setup the plugin configuration
---@param user_config screw.Config?
function M.setup(user_config)
  M.options = internal_config.create_config(user_config)
end

--- Get the current configuration
---@return screw.InternalConfig
function M.get()
  return M.options
end

--- Get a specific configuration value using dot notation
---@param key string Dot-separated key path (e.g., "ui.float_window.width")
---@return any The configuration value
function M.get_option(key)
  local keys = vim.split(key, ".", { plain = true })
  local value = M.options
  
  for _, k in ipairs(keys) do
    if type(value) == "table" and value[k] ~= nil then
      value = value[k]
    else
      error(string.format("Configuration key '%s' not found", key))
    end
  end
  
  return value
end

--- Check if the plugin is configured (has non-default settings)
---@return boolean
function M.is_configured()
  return vim.g.screw_nvim ~= nil
end

return M