--- Export functionality for screw.nvim
---
--- This module handles exporting notes to various formats.
---

local utils = require("screw.utils")
local config = require("screw.config")

local M = {}

--- Export notes to specified format
---@param options ScrewExportOptions
---@return boolean
function M.export_notes(options)
  -- Validate options
  if not options or not options.format then
    utils.error("Export format is required")
    return false
  end

  -- Get notes manager
  local notes_manager = require("screw.notes.manager")
  local notes = notes_manager.get_notes(options.filter)

  if #notes == 0 then
    utils.warn("No notes found to export")
    return false
  end

  -- Determine output path (ensure it's absolute)
  local output_path = options.output_path
  if not output_path then
    local export_config = config.get_option("export")
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename = "screw_notes_" .. timestamp .. "." .. options.format
    output_path = export_config.output_dir .. "/" .. filename
  end

  -- Ensure output path is absolute
  output_path = utils.get_absolute_path(output_path)

  -- Load appropriate exporter
  local exporter_module = "screw.export." .. options.format
  local has_exporter, exporter = pcall(require, exporter_module)

  if not has_exporter then
    utils.error("Unsupported export format: " .. options.format)
    return false
  end

  -- Export notes
  local content = exporter.export(notes, options)
  if not content then
    utils.error("Failed to generate export content")
    return false
  end

  -- Write to file
  local dir = vim.fn.fnamemodify(output_path, ":h")
  utils.ensure_dir(dir)

  if utils.write_file(output_path, content) then
    utils.info("Notes exported to: " .. output_path)
    return true
  else
    utils.error("Failed to write export file: " .. output_path)
    return false
  end
end

--- Get list of supported export formats
---@return string[]
function M.get_supported_formats()
  return { "markdown", "json", "csv", "sarif" }
end

--- Validate export options
---@param options ScrewExportOptions
---@return boolean, string?
function M.validate_options(options)
  if not options then
    return false, "Options table is required"
  end

  if not options.format then
    return false, "Export format is required"
  end

  local supported_formats = M.get_supported_formats()
  if not vim.tbl_contains(supported_formats, options.format) then
    return false, "Unsupported format: " .. options.format .. ". Supported: " .. table.concat(supported_formats, ", ")
  end

  if options.output_path and type(options.output_path) ~= "string" then
    return false, "Output path must be a string"
  end

  return true
end

return M
