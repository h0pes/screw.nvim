--- CSV exporter for screw.nvim
---
--- This module exports notes to CSV format.
---

local utils = require("screw.utils")

local M = {}

--- Export notes to CSV format
---@param notes ScrewNote[]
---@param options ScrewExportOptions
---@return string?
function M.export(notes, options)
  local lines = {}
  
  -- Add CSV header
  local headers = {
    "ID",
    "File Path",
    "Line Number",
    "Author",
    "Timestamp",
    "State",
    "Severity",
    "CWE",
    "Comment",
    "Description",
  }
  
  -- Add reply columns if requested
  if options.include_replies ~= false then
    table.insert(headers, "Reply Count")
    table.insert(headers, "Replies")
  end
  
  table.insert(lines, M.escape_csv_row(headers))
  
  -- Add notes
  for _, note in ipairs(notes) do
    local row = {
      note.id,
      note.file_path,
      tostring(note.line_number),
      note.author,
      note.timestamp,
      note.state,
      note.severity or "",
      note.cwe or "",
      note.comment,
      note.description or "",
    }
    
    -- Add reply information if requested
    if options.include_replies ~= false then
      local reply_count = note.replies and #note.replies or 0
      table.insert(row, tostring(reply_count))
      
      local reply_text = ""
      if note.replies and #note.replies > 0 then
        local reply_parts = {}
        for _, reply in ipairs(note.replies) do
          table.insert(reply_parts, string.format("[%s by %s] %s", 
            reply.timestamp, reply.author, reply.comment))
        end
        reply_text = table.concat(reply_parts, " | ")
      end
      table.insert(row, reply_text)
    end
    
    table.insert(lines, M.escape_csv_row(row))
  end
  
  return table.concat(lines, "\n")
end

--- Escape a CSV row
---@param row string[]
---@return string
function M.escape_csv_row(row)
  local escaped = {}
  
  for _, field in ipairs(row) do
    local escaped_field = tostring(field or "")
    
    -- Escape quotes and wrap in quotes if necessary
    if escaped_field:find('[",\n\r]') then
      escaped_field = '"' .. escaped_field:gsub('"', '""') .. '"'
    end
    
    table.insert(escaped, escaped_field)
  end
  
  return table.concat(escaped, ",")
end

--- Escape special characters in CSV field
---@param text string
---@return string
function M.escape_csv_field(text)
  if not text then
    return ""
  end
  
  text = tostring(text)
  
  -- Replace newlines with spaces
  text = text:gsub("[\r\n]", " ")
  
  -- Handle quotes and commas
  if text:find('[",]') then
    text = '"' .. text:gsub('"', '""') .. '"'
  end
  
  return text
end

return M