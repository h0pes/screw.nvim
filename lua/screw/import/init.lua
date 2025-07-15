--- Import functionality for screw.nvim
---
--- This module handles importing notes from SAST tools.
---

local utils = require("screw.utils")
local config = require("screw.config")

local M = {}

--- Import notes from SAST tools
---@param options ScrewImportOptions
---@return boolean
function M.import_notes(options)
  -- Validate options
  if not options or not options.tool or not options.input_path then
    utils.error("Tool and input path are required for import")
    return false
  end
  
  -- Ensure input path is absolute and check if file exists
  local input_path = utils.get_absolute_path(options.input_path)
  if not utils.file_exists(input_path) then
    utils.error("Input file does not exist: " .. input_path)
    return false
  end
  
  -- Load appropriate importer
  local importer_module = "screw.import." .. options.tool
  local has_importer, importer = pcall(require, importer_module)
  
  if not has_importer then
    utils.error("Unsupported import tool: " .. options.tool)
    return false
  end
  
  -- Read input file
  local content = utils.read_file(input_path)
  if not content then
    utils.error("Failed to read input file: " .. input_path)
    return false
  end
  
  -- Parse content
  local notes = importer.parse(content, options)
  if not notes or #notes == 0 then
    utils.warn("No notes found in input file")
    return false
  end
  
  -- Import notes using notes manager
  local notes_manager = require("screw.notes.manager")
  local imported_count = 0
  
  for _, note_data in ipairs(notes) do
    -- Set default author if not provided
    if not note_data.author then
      note_data.author = options.author or utils.get_author()
    end
    
    -- Auto-classify if requested
    if options.auto_classify then
      note_data.state = M.auto_classify_state(note_data)
    end
    
    -- Create note
    if notes_manager.create_note(note_data) then
      imported_count = imported_count + 1
    end
  end
  
  if imported_count > 0 then
    utils.info(string.format("Successfully imported %d notes from %s", imported_count, options.tool))
    return true
  else
    utils.error("Failed to import any notes")
    return false
  end
end

--- Auto-classify vulnerability state based on note data
---@param note_data table
---@return string
function M.auto_classify_state(note_data)
  -- Default classification logic
  if note_data.severity then
    local severity = note_data.severity:lower()
    if severity == "high" or severity == "critical" then
      return "vulnerable"
    elseif severity == "low" or severity == "info" then
      return "not_vulnerable"
    end
  end
  
  -- Default to todo for manual review
  return "todo"
end

--- Get list of supported import tools
---@return string[]
function M.get_supported_tools()
  return { "semgrep", "bandit", "gosec", "sonarqube" }
end

--- Validate import options
---@param options ScrewImportOptions
---@return boolean, string?
function M.validate_options(options)
  if not options then
    return false, "Options table is required"
  end
  
  if not options.tool then
    return false, "Tool is required"
  end
  
  if not options.input_path then
    return false, "Input path is required"
  end
  
  local supported_tools = M.get_supported_tools()
  if not vim.tbl_contains(supported_tools, options.tool) then
    return false, "Unsupported tool: " .. options.tool .. ". Supported: " .. table.concat(supported_tools, ", ")
  end
  
  if type(options.input_path) ~= "string" then
    return false, "Input path must be a string"
  end
  
  return true
end

return M