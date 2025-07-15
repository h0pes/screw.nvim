--- JSON exporter for screw.nvim
---
--- This module exports notes to JSON format.
---

local utils = require("screw.utils")

local M = {}

--- Export notes to JSON format
---@param notes ScrewNote[]
---@param options ScrewExportOptions
---@return string?
function M.export(notes, options)
  -- Prepare export data
  local export_data = {
    metadata = {
      plugin = "screw.nvim",
      version = "1.0.0",
      exported_at = utils.get_timestamp(),
      total_notes = #notes,
      format = "json",
    },
    notes = {},
  }

  -- Process notes
  for _, note in ipairs(notes) do
    local exported_note = {
      id = note.id,
      file_path = note.file_path,
      line_number = note.line_number,
      author = note.author,
      timestamp = note.timestamp,
      comment = note.comment,
      state = note.state,
    }

    -- Add optional fields
    if note.description then
      exported_note.description = note.description
    end

    if note.severity then
      exported_note.severity = note.severity
    end

    if note.cwe then
      exported_note.cwe = note.cwe
    end

    -- Add replies if requested and available
    if options.include_replies ~= false and note.replies and #note.replies > 0 then
      exported_note.replies = {}
      for _, reply in ipairs(note.replies) do
        table.insert(exported_note.replies, {
          id = reply.id,
          parent_id = reply.parent_id,
          author = reply.author,
          timestamp = reply.timestamp,
          comment = reply.comment,
        })
      end
    end

    table.insert(export_data.notes, exported_note)
  end

  -- Calculate statistics
  export_data.statistics = M.calculate_stats(notes)

  -- Encode to JSON
  local success, json_str = pcall(vim.json.encode, export_data)
  if not success then
    return nil
  end

  return json_str
end

--- Calculate statistics for notes
---@param notes ScrewNote[]
---@return table
function M.calculate_stats(notes)
  local stats = {
    total = #notes,
    by_state = {
      vulnerable = 0,
      not_vulnerable = 0,
      todo = 0,
    },
    by_severity = {
      high = 0,
      medium = 0,
      low = 0,
      info = 0,
    },
    by_author = {},
    by_cwe = {},
    by_file = {},
  }

  for _, note in ipairs(notes) do
    -- Count by state
    stats.by_state[note.state] = stats.by_state[note.state] + 1

    -- Count by severity
    if note.severity then
      stats.by_severity[note.severity] = stats.by_severity[note.severity] + 1
    end

    -- Count by author
    stats.by_author[note.author] = (stats.by_author[note.author] or 0) + 1

    -- Count by CWE
    if note.cwe then
      stats.by_cwe[note.cwe] = (stats.by_cwe[note.cwe] or 0) + 1
    end

    -- Count by file
    stats.by_file[note.file_path] = (stats.by_file[note.file_path] or 0) + 1
  end

  return stats
end

return M