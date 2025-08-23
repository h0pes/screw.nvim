--- Minimal Neovim configuration for API documentation generation
---
--- This file provides the minimal setup needed to generate API documentation
--- using mini.doc without loading the full user configuration.

-- Set vim.opt.runtimepath to include the plugin directory
vim.opt.runtimepath:append(".")

-- Add current directory to package.path for local module loading
local current_dir = vim.fn.getcwd()
package.path = current_dir .. "/lua/?.lua;" .. current_dir .. "/lua/?/init.lua;" .. package.path

-- Add LuaRocks local path for mini.doc - try multiple common locations
local home = os.getenv("HOME")
if home then
  -- Standard LuaRocks paths
  local luarocks_paths = {
    home .. "/.luarocks/share/lua/5.1/?.lua",
    home .. "/.luarocks/share/lua/5.1/?/init.lua",
    "/usr/local/share/lua/5.1/?.lua",
    "/usr/local/share/lua/5.1/?/init.lua",
    "/usr/share/lua/5.1/?.lua",
    "/usr/share/lua/5.1/?/init.lua"
  }
  
  for _, path in ipairs(luarocks_paths) do
    package.path = path .. ";" .. package.path
  end
  
  local luarocks_cpaths = {
    home .. "/.luarocks/lib/lua/5.1/?.so",
    "/usr/local/lib/lua/5.1/?.so", 
    "/usr/lib/lua/5.1/?.so"
  }
  
  for _, cpath in ipairs(luarocks_cpaths) do
    package.cpath = cpath .. ";" .. package.cpath
  end
end

-- Disable loading of user configurations
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set up minimal Neovim environment for documentation generation
vim.opt.compatible = false
vim.opt.loadplugins = false