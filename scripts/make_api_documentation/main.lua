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

--- Debug function to show package paths
local function debug_paths()
  print("=== Debugging package paths ===")
  print("package.path:", package.path)
  print("package.cpath:", package.cpath)
  
  -- Try to find mini.doc in different locations
  local paths_to_check = {}
  for path in package.path:gmatch("([^;]+)") do
    local mini_doc_path = path:gsub("%?", "mini/doc")
    table.insert(paths_to_check, mini_doc_path)
  end
  
  print("Checking for mini.doc at these locations:")
  for _, path in ipairs(paths_to_check) do
    local exists = vim.fn.filereadable(path) == 1
    print("  " .. path .. " : " .. (exists and "EXISTS" or "not found"))
  end
end

--- Generate basic API documentation as fallback
local function generate_basic_docs()
  print("Generating basic API documentation as fallback...")
  
  local api_content = [[==============================================================================
screw.nvim API Documentation                                    *screw_api.txt*

Auto-generated API documentation for screw.nvim security code review plugin.

==============================================================================
FUNCTIONS                                                      *screw-api-functions*

For detailed API documentation, see the source files:
- lua/screw/init.lua      - Main plugin API functions
- lua/screw/types.lua     - Type definitions  
- lua/screw/config/meta.lua - Configuration types

Main API functions available:
- setup()                 - Initialize the plugin (optional)
- create_note()           - Create a new security note
- view_current_line_notes() - View notes for current line
- get_notes()             - Get all notes with optional filtering
- export_notes()          - Export notes to various formats
- import_notes()          - Import SARIF findings
- jump_next()             - Jump to next security note
- jump_prev()             - Jump to previous security note

For complete function signatures and detailed documentation,
use LSP or refer to the source code with LuaCATS annotations.

==============================================================================
 vim:tw=78:ts=8:noet:ft=help:norl:
]]

  local types_content = [[==============================================================================
screw.nvim Type Definitions                                   *screw_types.txt*

Auto-generated type documentation for screw.nvim.

==============================================================================
CORE TYPES                                                    *screw-core-types*

ScrewNote                                                          *ScrewNote*
  Main note structure for security annotations

ScrewReply                                                        *ScrewReply*  
  Reply structure for threaded discussions

screw.Config                                                   *screw.Config*
  Main plugin configuration

For detailed type definitions with all fields and descriptions,
refer to:
- lua/screw/types.lua     - Core note and reply types
- lua/screw/config/meta.lua - Configuration types with full field documentation

==============================================================================
 vim:tw=78:ts=8:noet:ft=help:norl:
]]

  -- Write the files
  local api_file = io.open("doc/screw_api.txt", "w")
  if api_file then
    api_file:write(api_content)
    api_file:close()
    print("Generated basic doc/screw_api.txt")
  else
    print("ERROR: Could not write doc/screw_api.txt")
    return false
  end
  
  local types_file = io.open("doc/screw_types.txt", "w")
  if types_file then
    types_file:write(types_content)  
    types_file:close()
    print("Generated basic doc/screw_types.txt")
  else
    print("ERROR: Could not write doc/screw_types.txt")
    return false
  end
  
  return true
end

--- Main function to generate API documentation
local function main()
  local project_root = _get_project_root()
  
  -- Change to project root directory
  vim.cmd("cd " .. project_root)
  
  -- Debug package paths
  debug_paths()
  
  -- Try to load mini.doc
  local ok, mini_doc = pcall(require, "mini.doc")
  if not ok then
    print("NOTICE: mini.doc not available (" .. tostring(mini_doc) .. ")")
    print("Falling back to basic documentation generation...")
    return generate_basic_docs()
  end

  print("Found mini.doc, generating full API documentation...")

  -- Configure mini.doc to not include module in signature
  local original_enable = mini_doc.config and mini_doc.config.enable_module_in_signature
  if mini_doc.config then
    mini_doc.config.enable_module_in_signature = false
  end

  -- Generate API documentation
  local success, error_msg = pcall(function()
    mini_doc.generate({
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

  -- Restore original mini.doc configuration
  if mini_doc.config and original_enable ~= nil then
    mini_doc.config.enable_module_in_signature = original_enable
  end

  if not success then
    print("ERROR generating documentation with mini.doc: " .. (error_msg or "Unknown error"))
    print("Falling back to basic documentation generation...")
    return generate_basic_docs()
  end

  print("Successfully generated API documentation with mini.doc:")
  print("  - doc/screw_api.txt")
  print("  - doc/screw_types.txt")
  return true
end

-- Execute main function
main()