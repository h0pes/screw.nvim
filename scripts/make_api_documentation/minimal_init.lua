--- Minimal Neovim configuration for API documentation generation
---
--- This file provides the minimal setup needed to generate API documentation
--- using vimdoc without loading the full user configuration.

-- Set vim.opt.runtimepath to include the plugin directory
vim.opt.runtimepath:append(".")

-- Add current directory to package.path for local module loading
local current_dir = vim.fn.getcwd()
package.path = current_dir .. "/lua/?.lua;" .. current_dir .. "/lua/?/init.lua;" .. package.path

-- Disable loading of user configurations
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set up minimal Neovim environment for documentation generation
vim.opt.compatible = false
vim.opt.loadplugins = false