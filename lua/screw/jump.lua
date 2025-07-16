--- Jump functionality for screw.nvim
---
--- This module provides jump_next and jump_prev functionality
--- to navigate between security notes in the current buffer.
---

local utils = require("screw.utils")
local config = require("screw.config")
local storage = require("screw.notes.storage")

local M = {}

--- Get all notes for the current buffer sorted by line number
---@return ScrewNote[]
local function get_current_buffer_notes()
  local buffer_info = utils.get_buffer_info()
  if not buffer_info.filepath or buffer_info.filepath == "" then
    return {}
  end

  local all_notes = storage.get_all_notes()
  local buffer_notes = {}

  for _, note in ipairs(all_notes) do
    if note.file_path == buffer_info.relative_path then
      table.insert(buffer_notes, note)
    end
  end

  -- Sort by line number
  table.sort(buffer_notes, function(a, b)
    return a.line_number < b.line_number
  end)

  return buffer_notes
end

--- Check if a note matches any of the specified keywords
---@param note ScrewNote
---@param keywords string[]?
---@return boolean
local function note_matches_keywords(note, keywords)
  if not keywords or #keywords == 0 then
    return true
  end

  -- Get configured keywords for each state
  local signs_config = config.get_option("signs")
  local state_keywords = signs_config.keywords[note.state] or {}

  -- Check if any of the specified keywords match this note's state keywords
  for _, keyword in ipairs(keywords) do
    for _, state_keyword in ipairs(state_keywords) do
      if keyword:upper() == state_keyword:upper() then
        return true
      end
    end
  end

  return false
end

--- Jump to the next note in the current buffer
---@param opts table? Options table with optional keywords filter
function M.jump_next(opts)
  opts = opts or {}
  local keywords = opts.keywords

  local notes = get_current_buffer_notes()
  if #notes == 0 then
    utils.info("No security notes found in current buffer")
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local target_note = nil

  -- Find next note after current line
  for _, note in ipairs(notes) do
    if note.line_number > current_line and note_matches_keywords(note, keywords) then
      target_note = note
      break
    end
  end

  -- If no note found after current line, wrap to first matching note
  if not target_note then
    for _, note in ipairs(notes) do
      if note_matches_keywords(note, keywords) then
        target_note = note
        break
      end
    end
  end

  if target_note then
    vim.api.nvim_win_set_cursor(0, { target_note.line_number, 0 })
    -- Center the line in the window
    vim.cmd("normal! zz")

    -- Show brief info about the note
    local severity_text = target_note.severity and (" [" .. target_note.severity:upper() .. "]") or ""
    local state_text = target_note.state:gsub("_", " "):upper()
    utils.info(
      string.format(
        "Note %s%s: %s",
        state_text,
        severity_text,
        target_note.comment:sub(1, 50) .. (string.len(target_note.comment) > 50 and "..." or "")
      )
    )
  else
    local keyword_text = keywords and (" matching " .. table.concat(keywords, ", ")) or ""
    utils.info("No security notes" .. keyword_text .. " found in current buffer")
  end
end

--- Jump to the previous note in the current buffer
---@param opts table? Options table with optional keywords filter
function M.jump_prev(opts)
  opts = opts or {}
  local keywords = opts.keywords

  local notes = get_current_buffer_notes()
  if #notes == 0 then
    utils.info("No security notes found in current buffer")
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local target_note = nil

  -- Find previous note before current line (search backwards)
  for i = #notes, 1, -1 do
    local note = notes[i]
    if note.line_number < current_line and note_matches_keywords(note, keywords) then
      target_note = note
      break
    end
  end

  -- If no note found before current line, wrap to last matching note
  if not target_note then
    for i = #notes, 1, -1 do
      local note = notes[i]
      if note_matches_keywords(note, keywords) then
        target_note = note
        break
      end
    end
  end

  if target_note then
    vim.api.nvim_win_set_cursor(0, { target_note.line_number, 0 })
    -- Center the line in the window
    vim.cmd("normal! zz")

    -- Show brief info about the note
    local severity_text = target_note.severity and (" [" .. target_note.severity:upper() .. "]") or ""
    local state_text = target_note.state:gsub("_", " "):upper()
    utils.info(
      string.format(
        "Note %s%s: %s",
        state_text,
        severity_text,
        target_note.comment:sub(1, 50) .. (string.len(target_note.comment) > 50 and "..." or "")
      )
    )
  else
    local keyword_text = keywords and (" matching " .. table.concat(keywords, ", ")) or ""
    utils.info("No security notes" .. keyword_text .. " found in current buffer")
  end
end

return M
