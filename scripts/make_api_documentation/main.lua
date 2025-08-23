--- API documentation generation script for screw.nvim
---
--- This script uses vimdoc to generate API documentation from LuaCATS annotations
--- in the source code, following the nvim-best-practices-plugin-template pattern.

--- Get the directory where this script is located
---@return string
local function _get_script_directory()
  local info = debug.getinfo(1, "S")
  local script_path = info.source:match("^@(.+)")
  return vim.fn.fnamemodify(script_path, ":h")
end

--- Get the project root directory (two levels up from script directory)
---@return string
local function _get_project_root()
  local script_dir = _get_script_directory()
  return vim.fn.fnamemodify(script_dir, ":h:h")
end

--- Main function to generate API documentation
local function main()
  local project_root = _get_project_root()
  
  -- Change to project root directory
  vim.cmd("cd " .. project_root)
  
  -- Load vimdoc (mini.doc alternative that works better with vimdoc format)
  local ok, vimdoc = pcall(require, "mini.doc")
  if not ok then
    print("ERROR: mini.doc not available. Install with: luarocks install mini.doc")
    return false
  end

  -- Configure vimdoc to not include module in signature
  local original_enable = vimdoc.config.enable_module_in_signature
  vimdoc.config.enable_module_in_signature = false

  -- Generate API documentation
  local success, error_msg = pcall(function()
    vimdoc.generate({
      -- Source files to extract documentation from
      source = {
        "lua/screw/init.lua",      -- Main API functions
        "lua/screw/types.lua",     -- Core types  
        "lua/screw/config/meta.lua" -- Configuration types
      },
      -- Output documentation files
      destination = {
        "doc/screw_api.txt",    -- API reference
        "doc/screw_types.txt",  -- Type definitions
      }
    })
  end)

  -- Restore original vimdoc configuration
  vimdoc.config.enable_module_in_signature = original_enable

  if not success then
    print("ERROR generating documentation: " .. (error_msg or "Unknown error"))
    return false
  end

  print("Successfully generated API documentation:")
  print("  - doc/screw_api.txt")
  print("  - doc/screw_types.txt")
  return true
end

-- Execute main function
main()