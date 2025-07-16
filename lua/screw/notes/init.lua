--- Notes module entry point for screw.nvim
---
--- This module exposes the note management API and serves as the main
--- interface for note operations.
---

local manager = require("screw.notes.manager")
local ui = require("screw.notes.ui")
local storage = require("screw.notes.storage")

local M = {}

--- Initialize notes subsystem
function M.setup()
  manager.setup()
  ui.setup()
end

--- Create a new note
---@param opts table?
---@return ScrewNote?
function M.create_note(opts)
  return manager.create_note(opts or {})
end

--- Get all notes
---@param filter ScrewNoteFilter?
---@return ScrewNote[]
function M.get_notes(filter)
  return manager.get_notes(filter)
end

--- Get notes for current file
---@return ScrewNote[]
function M.get_current_file_notes()
  return manager.get_current_file_notes()
end

--- Get notes for current line
---@return ScrewNote[]
function M.get_current_line_notes()
  return manager.get_current_line_notes()
end

--- Get note by ID
---@param id string
---@return ScrewNote?
function M.get_note_by_id(id)
  return manager.get_note_by_id(id)
end

--- Update a note
---@param id string
---@param updates table
---@return boolean
function M.update_note(id, updates)
  return manager.update_note(id, updates)
end

--- Delete a note
---@param id string
---@return boolean
function M.delete_note(id)
  return manager.delete_note(id)
end

--- Add a reply to a note
---@param parent_id string
---@param comment string
---@param author string?
---@return boolean
function M.add_reply(parent_id, comment, author)
  return manager.add_reply(parent_id, comment, author)
end

--- Get statistics
---@return table
function M.get_statistics()
  return manager.get_statistics()
end

--- UI functions
function M.open_create_note_window()
  ui.open_create_note_window()
end

function M.open_view_notes_window()
  ui.open_view_notes_window()
end

function M.open_file_notes_window()
  ui.open_file_notes_window()
end

function M.open_all_notes_window()
  ui.open_all_notes_window()
end

--- Storage functions
function M.force_save()
  return storage.force_save()
end

function M.get_storage_stats()
  return storage.get_storage_stats()
end

--- Event hooks for extensibility
M.hooks = {
  pre_create = {},
  post_create = {},
  pre_update = {},
  post_update = {},
  pre_delete = {},
  post_delete = {},
}

--- Register a hook
---@param hook_name string
---@param callback function
function M.register_hook(hook_name, callback)
  if M.hooks[hook_name] then
    table.insert(M.hooks[hook_name], callback)
  end
end

--- Execute hooks
---@param hook_name string
---@param data table
function M.execute_hooks(hook_name, data)
  local hooks = M.hooks[hook_name]
  if not hooks then
    return
  end

  for _, callback in ipairs(hooks) do
    pcall(callback, data)
  end
end

return M
