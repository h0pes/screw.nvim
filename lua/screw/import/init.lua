--- Import functionality for screw.nvim
---
--- This module handles importing security findings from SARIF files.
---

local utils = require("screw.utils")

local M = {}

--- Import security findings from SARIF file
---@param options ScrewImportOptions
---@return ScrewImportResult
function M.import_sarif(options)
  -- Validate options
  local valid, error_msg = M.validate_options(options)
  if not valid then
    local result = {
      success = false,
      total_findings = 0,
      imported_count = 0,
      skipped_count = 0,
      collision_count = 0,
      error_count = 1,
      tool_name = "Unknown",
      sarif_file_path = options.input_path or "",
      errors = { error_msg },
    }
    return result
  end

  -- Ensure input path is absolute and check if file exists
  local input_path = utils.get_absolute_path(options.input_path)
  if not utils.file_exists(input_path) then
    local result = {
      success = false,
      total_findings = 0,
      imported_count = 0,
      skipped_count = 0,
      collision_count = 0,
      error_count = 1,
      tool_name = "Unknown",
      sarif_file_path = input_path,
      errors = { "Input file does not exist: " .. input_path },
    }
    return result
  end

  -- Use SARIF importer
  local sarif_importer = require("screw.import.sarif")
  local result = sarif_importer.import(input_path, options)

  -- Show results to user
  sarif_importer.show_import_results(result)

  return result
end

--- Get list of supported import formats
---@return string[]
function M.get_supported_formats()
  return { "sarif" }
end

--- Validate import options
---@param options ScrewImportOptions
---@return boolean, string?
function M.validate_options(options)
  if not options then
    return false, "Options table is required"
  end

  if not options.format then
    return false, "Format is required"
  end

  if not options.input_path then
    return false, "Input path is required"
  end

  local supported_formats = M.get_supported_formats()
  if not vim.tbl_contains(supported_formats, options.format) then
    return false, "Unsupported format: " .. options.format .. ". Supported: " .. table.concat(supported_formats, ", ")
  end

  if type(options.input_path) ~= "string" then
    return false, "Input path must be a string"
  end

  -- Validate collision strategy
  if options.collision_strategy then
    local valid_strategies = { "ask", "skip", "overwrite", "merge" }
    if not vim.tbl_contains(valid_strategies, options.collision_strategy) then
      return false, "Invalid collision strategy: " .. options.collision_strategy
    end
  end

  return true
end

return M
