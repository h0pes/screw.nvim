--- Markdown exporter for screw.nvim
---
--- This module exports notes to Markdown format.
---

-- local utils = require("screw.utils")

local M = {}

--- Export notes to Markdown format
---@param notes ScrewNote[]
---@param options ScrewExportOptions
---@return string?
function M.export(notes, options)
  local lines = {}

  -- Add header
  table.insert(lines, "# Security Code Review Notes")
  table.insert(lines, "")
  table.insert(lines, "Generated on: " .. os.date("%Y-%m-%d %H:%M:%S"))
  table.insert(lines, "Total notes: " .. #notes)
  table.insert(lines, "")

  -- Add table of contents
  table.insert(lines, "## Table of Contents")
  table.insert(lines, "")

  local files = {}
  for _, note in ipairs(notes) do
    if not vim.tbl_contains(files, note.file_path) then
      table.insert(files, note.file_path)
    end
  end

  for i, file in ipairs(files) do
    table.insert(lines, string.format("%d. [%s](#%s)", i, file, M.create_anchor(file)))
  end

  table.insert(lines, "")

  -- Group notes by file
  local notes_by_file = {}
  for _, note in ipairs(notes) do
    if not notes_by_file[note.file_path] then
      notes_by_file[note.file_path] = {}
    end
    table.insert(notes_by_file[note.file_path], note)
  end

  -- Export notes for each file
  for _, file in ipairs(files) do
    table.insert(lines, "## " .. file)
    table.insert(lines, "")

    local file_notes = notes_by_file[file]

    -- Sort notes by line number
    table.sort(file_notes, function(a, b)
      return a.line_number < b.line_number
    end)

    for _, note in ipairs(file_notes) do
      M.export_note(lines, note, options)
    end

    table.insert(lines, "")
  end

  -- Add summary
  table.insert(lines, "## Summary")
  table.insert(lines, "")

  local stats = M.calculate_stats(notes)
  table.insert(lines, "- **Total notes**: " .. stats.total)
  table.insert(lines, "- **Vulnerable**: " .. stats.vulnerable)
  table.insert(lines, "- **Not vulnerable**: " .. stats.not_vulnerable)
  table.insert(lines, "- **Todo**: " .. stats.todo)
  table.insert(lines, "")

  -- Add severity breakdown if there are notes with severity
  if
    stats.by_severity.high > 0
    or stats.by_severity.medium > 0
    or stats.by_severity.low > 0
    or stats.by_severity.info > 0
  then
    table.insert(lines, "### By Severity")
    table.insert(lines, "")
    table.insert(lines, "- **High**: " .. stats.by_severity.high)
    table.insert(lines, "- **Medium**: " .. stats.by_severity.medium)
    table.insert(lines, "- **Low**: " .. stats.by_severity.low)
    table.insert(lines, "- **Info**: " .. stats.by_severity.info)
    table.insert(lines, "")
  end

  if not vim.tbl_isempty(stats.by_cwe) then
    table.insert(lines, "### By CWE")
    table.insert(lines, "")

    local cwes = vim.tbl_keys(stats.by_cwe)
    table.sort(cwes)

    for _, cwe in ipairs(cwes) do
      table.insert(lines, "- **" .. cwe .. "**: " .. stats.by_cwe[cwe])
    end

    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

--- Export a single note to Markdown
---@param lines string[]
---@param note ScrewNote
---@param options ScrewExportOptions
function M.export_note(lines, note, options)
  local state_emoji = {
    vulnerable = "🔴",
    not_vulnerable = "✅",
    todo = "📝",
  }

  -- Note header
  table.insert(
    lines,
    string.format(
      "### %s Line %d - %s",
      state_emoji[note.state] or "S",
      note.line_number,
      note.state:gsub("_", " "):upper()
    )
  )
  table.insert(lines, "")

  -- Metadata
  table.insert(lines, "**Author**: " .. note.author)
  table.insert(lines, "**Created**: " .. note.timestamp)

  if note.severity then
    table.insert(lines, "**Severity**: " .. note.severity:upper())
  end

  if note.cwe then
    table.insert(lines, "**CWE**: " .. note.cwe)
  end

  table.insert(lines, "")

  -- Comment
  table.insert(lines, "**Comment**:")
  table.insert(lines, "")
  table.insert(lines, note.comment)
  table.insert(lines, "")

  -- Description
  if note.description then
    table.insert(lines, "**Description**:")
    table.insert(lines, "")
    table.insert(lines, note.description)
    table.insert(lines, "")
  end

  -- Replies
  if options.include_replies ~= false and note.replies and #note.replies > 0 then
    table.insert(lines, "**Replies**:")
    table.insert(lines, "")

    for i, reply in ipairs(note.replies) do
      table.insert(lines, string.format("*Reply %d by %s (%s):*", i, reply.author, reply.timestamp))
      table.insert(lines, "")
      table.insert(lines, reply.comment)
      table.insert(lines, "")
    end
  end

  table.insert(lines, "---")
  table.insert(lines, "")
end

--- Create anchor for file links
---@param text string
---@return string
function M.create_anchor(text)
  return text:lower():gsub("[^%w%-_]", "-"):gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", "")
end

--- Calculate statistics for notes
---@param notes ScrewNote[]
---@return table
function M.calculate_stats(notes)
  local stats = {
    total = #notes,
    vulnerable = 0,
    not_vulnerable = 0,
    todo = 0,
    by_severity = {
      high = 0,
      medium = 0,
      low = 0,
      info = 0,
    },
    by_cwe = {},
  }

  for _, note in ipairs(notes) do
    stats[note.state] = stats[note.state] + 1

    if note.severity then
      stats.by_severity[note.severity] = stats.by_severity[note.severity] + 1
    end

    if note.cwe then
      stats.by_cwe[note.cwe] = (stats.by_cwe[note.cwe] or 0) + 1
    end
  end

  return stats
end

return M
