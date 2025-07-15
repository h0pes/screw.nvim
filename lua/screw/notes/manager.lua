--- Notes manager for screw.nvim
---
--- This module handles note creation, retrieval, updates, and deletion.
---

local utils = require("screw.utils")
local storage = require("screw.notes.storage")

local M = {}

--- Initialize the notes manager
function M.setup()
  storage.setup()
end

--- Create a new note
---@param opts table
---@param buffer_info table? Optional buffer info (if not provided, gets current buffer info)
---@return ScrewNote?
function M.create_note(opts, buffer_info)
  -- Use provided buffer_info or get current buffer info
  buffer_info = buffer_info or utils.get_buffer_info()
  
  if not buffer_info.filepath or buffer_info.filepath == "" then
    utils.error("Cannot create note: no file open")
    return nil
  end
  
  -- Validate required fields
  if not opts.comment or opts.comment == "" then
    utils.error("Cannot create note: comment is required")
    return nil
  end
  
  -- Validate optional CWE
  if opts.cwe and not utils.is_valid_cwe(opts.cwe) then
    utils.error("Invalid CWE format. Use format: CWE-123")
    return nil
  end
  
  -- Validate state
  if opts.state and not utils.is_valid_state(opts.state) then
    utils.error("Invalid state. Must be: vulnerable, not_vulnerable, or todo")
    return nil
  end
  
  -- Validate severity
  if opts.severity and not utils.is_valid_severity(opts.severity) then
    utils.error("Invalid severity. Must be: high, medium, low, or info")
    return nil
  end
  
  -- Check if severity is required for vulnerable state
  if opts.state == "vulnerable" and not opts.severity then
    utils.error("Severity is required when state is 'vulnerable'")
    return nil
  end
  
  -- Build note with proper error handling
  local note_id = utils.generate_id()
  local author = opts.author
  if not author then
    local success, result = pcall(utils.get_author)
    if success then
      author = result
    else
      utils.error("Failed to get author: " .. tostring(result))
      author = "unknown"
    end
  end
  
  local note = {
    id = note_id,
    file_path = buffer_info.relative_path,
    line_number = buffer_info.line_number,
    author = author,
    timestamp = utils.get_timestamp(),
    comment = opts.comment,
    description = opts.description,
    cwe = opts.cwe,
    state = opts.state,
    severity = opts.severity,
    replies = {},
  }
  
  -- Save note
  if storage.save_note(note) then
    -- Broadcast change if collaboration is enabled
    local success, collaboration = pcall(require, "screw.collaboration")
    if success and collaboration.enabled then
      pcall(collaboration.broadcast_note_change, note, "create")
    end
    
    -- Update signs
    local signs_success, signs = pcall(require, "screw.signs")
    if signs_success then
      pcall(signs.on_note_added, note)
    end
    
    utils.info("Note created successfully")
    return note
  else
    utils.error("Failed to save note")
    return nil
  end
end

--- Get all notes
---@param filter ScrewNoteFilter?
---@return ScrewNote[]
function M.get_notes(filter)
  local notes = storage.get_all_notes()
  
  if not filter then
    return notes
  end
  
  local filtered = {}
  for _, note in ipairs(notes) do
    local matches = true
    
    if filter.author and note.author ~= filter.author then
      matches = false
    end
    
    if filter.state and note.state ~= filter.state then
      matches = false
    end
    
    if filter.cwe and note.cwe ~= filter.cwe then
      matches = false
    end
    
    if filter.file_path and not note.file_path:find(filter.file_path, 1, true) then
      matches = false
    end
    
    if matches then
      table.insert(filtered, note)
    end
  end
  
  return filtered
end

--- Get notes for current file
---@return ScrewNote[]
function M.get_current_file_notes()
  local buffer_info = utils.get_buffer_info()
  
  if not buffer_info.filepath or buffer_info.filepath == "" then
    return {}
  end
  
  return M.get_notes({ file_path = buffer_info.relative_path })
end

--- Get notes for current line
---@return ScrewNote[]
function M.get_current_line_notes()
  local buffer_info = utils.get_buffer_info()
  
  if not buffer_info.filepath or buffer_info.filepath == "" then
    return {}
  end
  
  local notes = M.get_current_file_notes()
  local line_notes = {}
  
  for _, note in ipairs(notes) do
    if note.line_number == buffer_info.line_number then
      table.insert(line_notes, note)
    end
  end
  
  return line_notes
end

--- Get note by ID
---@param id string
---@return ScrewNote?
function M.get_note_by_id(id)
  return storage.get_note(id)
end

--- Update a note
---@param id string
---@param updates table
---@return boolean
function M.update_note(id, updates)
  local note = storage.get_note(id)
  if not note then
    utils.error("Note not found: " .. id)
    return false
  end
  
  -- Validate updates
  if updates.cwe and not utils.is_valid_cwe(updates.cwe) then
    utils.error("Invalid CWE format. Use format: CWE-123")
    return false
  end
  
  if updates.state and not utils.is_valid_state(updates.state) then
    utils.error("Invalid state. Must be: vulnerable, not_vulnerable, or todo")
    return false
  end
  
  -- Apply updates
  for key, value in pairs(updates) do
    if key ~= "id" and key ~= "timestamp" and key ~= "author" and key ~= "updated_at" then
      note[key] = value
    end
  end
  
  -- Set updated_at timestamp (preserve original timestamp)
  note.updated_at = utils.get_timestamp()
  
  if storage.save_note(note) then
    -- Broadcast change if collaboration is enabled
    local collaboration = require("screw.collaboration")
    if collaboration.enabled then
      collaboration.broadcast_note_change(note, "update")
    end
    
    -- Update signs (treat as delete + add to refresh properly)
    local signs_success, signs = pcall(require, "screw.signs")
    if signs_success then
      pcall(signs.on_note_deleted, note)
      pcall(signs.on_note_added, note)
    end
    
    utils.info("Note updated successfully")
    return true
  else
    utils.error("Failed to update note")
    return false
  end
end

--- Delete a note
---@param id string
---@return boolean
function M.delete_note(id)
  -- Get note before deletion for broadcasting
  local note = storage.get_note(id)
  
  if storage.delete_note(id) then
    -- Broadcast change if collaboration is enabled
    if note then
      local collaboration = require("screw.collaboration")
      if collaboration.enabled then
        collaboration.broadcast_note_change(note, "delete")
      end
    end
    
    -- Update signs
    if note then
      local signs_success, signs = pcall(require, "screw.signs")
      if signs_success then
        pcall(signs.on_note_deleted, note)
      end
    end
    
    utils.info("Note deleted successfully")
    return true
  else
    utils.error("Failed to delete note")
    return false
  end
end

--- Add a reply to a note
---@param parent_id string
---@param comment string
---@param author string?
---@return boolean
function M.add_reply(parent_id, comment, author)
  local note = storage.get_note(parent_id)
  if not note then
    utils.error("Note not found: " .. parent_id)
    return false
  end
  
  if not comment or comment == "" then
    utils.error("Reply comment cannot be empty")
    return false
  end
  
  local reply = {
    id = utils.generate_id(),
    parent_id = parent_id,
    author = author or utils.get_author(),
    timestamp = utils.get_timestamp(),
    comment = comment,
  }
  
  if not note.replies then
    note.replies = {}
  end
  
  table.insert(note.replies, reply)
  
  if storage.save_note(note) then
    utils.info("Reply added successfully")
    return true
  else
    utils.error("Failed to add reply")
    return false
  end
end

--- Get statistics about notes
---@return table
function M.get_statistics()
  local notes = storage.get_all_notes()
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
    by_author = {},
    by_cwe = {},
    files_with_notes = {},
  }
  
  for _, note in ipairs(notes) do
    -- Count by state
    stats[note.state] = stats[note.state] + 1
    
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
    
    -- Track files with notes
    if not vim.tbl_contains(stats.files_with_notes, note.file_path) then
      table.insert(stats.files_with_notes, note.file_path)
    end
  end
  
  return stats
end

return M