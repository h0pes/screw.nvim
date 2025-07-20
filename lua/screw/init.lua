--- Main API module for screw.nvim
---
--- This module provides the public API for the security code review plugin.
--- The plugin automatically initializes with sensible defaults - setup() is optional.
---

local M = {}

-- Plugin state tracking
local _initialized = false
local _user_config = nil

--- Ensure plugin is initialized with sensible defaults
local function ensure_initialized()
  if _initialized then
    return
  end

  -- Initialize project root early and store it
  local utils = require("screw.utils")
  local project_root = utils.get_project_root()
  vim.g.screw_project_root = project_root

  local config = require("screw.config")
  config.setup(_user_config)

  local notes_manager = require("screw.notes.manager")
  notes_manager.setup()

  local notes_ui = require("screw.notes.ui")
  notes_ui.setup()

  -- Initialize signs
  local signs = require("screw.signs")
  signs.setup()

  -- Initialize collaboration if enabled
  local collaboration = require("screw.collaboration")
  collaboration.setup()

  -- Set up autocommands for project lifecycle
  local augroup = vim.api.nvim_create_augroup("ScrewNvim", { clear = true })

  -- Save notes when leaving Neovim
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      local storage = require("screw.notes.storage")
      storage.force_save()

      -- Clean up collaboration
      local collaboration = require("screw.collaboration")
      collaboration.cleanup()
    end,
  })

  _initialized = true
end

--- Initialize the plugin (optional - plugin works without calling this)
---@param user_config screw.Config?
function M.setup(user_config)
  _user_config = user_config
  ensure_initialized()
end

--- Create a new note at the current cursor position
---@param opts table?
---@return ScrewNote?
function M.create_note(opts)
  ensure_initialized()
  opts = opts or {}

  local notes_ui = require("screw.notes.ui")
  local notes_manager = require("screw.notes.manager")

  -- If no comment provided, open UI to create note
  if not opts.comment then
    notes_ui.open_create_note_window()
    return nil
  end

  return notes_manager.create_note(opts)
end

--- View notes for the current line
function M.view_current_line_notes()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.open_view_notes_window()
end

--- View all notes for the current file
function M.view_current_file_notes()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.open_file_notes_window()
end

--- View all notes in the project
function M.view_all_notes()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.open_all_notes_window()
end

--- Get notes for the current line
---@return ScrewNote[]
function M.get_current_line_notes()
  ensure_initialized()
  local notes_manager = require("screw.notes.manager")
  return notes_manager.get_current_line_notes()
end

--- Get notes for the current file
---@return ScrewNote[]
function M.get_current_file_notes()
  ensure_initialized()
  local notes_manager = require("screw.notes.manager")
  return notes_manager.get_current_file_notes()
end

--- Get all notes
---@param filter ScrewNoteFilter?
---@return ScrewNote[]
function M.get_notes(filter)
  ensure_initialized()
  local notes_manager = require("screw.notes.manager")
  return notes_manager.get_notes(filter)
end

--- Update a note
---@param id string
---@param updates table
---@return boolean
function M.update_note(id, updates)
  ensure_initialized()
  local notes_manager = require("screw.notes.manager")
  return notes_manager.update_note(id, updates)
end

--- Edit a note (opens UI for note selection if multiple notes on line)
function M.edit_note()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.open_edit_current_line_notes()
end

--- Delete a note (opens UI for note selection if multiple notes on line)
function M.delete_note()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.open_delete_current_line_notes()
end

--- Delete all notes in current file (with confirmation)
function M.delete_current_file_notes()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.delete_current_file_notes_with_confirmation()
end

--- Delete all notes in project (with confirmation)
function M.delete_all_project_notes()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.delete_all_project_notes_with_confirmation()
end

--- Delete a note by ID (for programmatic use)
---@param id string
---@return boolean
function M.delete_note_by_id(id)
  ensure_initialized()
  local notes_manager = require("screw.notes.manager")
  return notes_manager.delete_note(id)
end

--- Reply to a note (opens UI for note selection if multiple notes on line)
function M.reply_to_note()
  ensure_initialized()
  local notes_ui = require("screw.notes.ui")
  notes_ui.open_reply_current_line_notes()
end

--- Add a reply to a note (for programmatic use)
---@param parent_id string
---@param comment string
---@param author string?
---@return boolean
function M.add_reply(parent_id, comment, author)
  ensure_initialized()
  local notes_manager = require("screw.notes.manager")
  return notes_manager.add_reply(parent_id, comment, author)
end

--- Export notes
---@param options ScrewExportOptions
---@return boolean
function M.export_notes(options)
  ensure_initialized()
  local export_module = require("screw.export.init")
  return export_module.export_notes(options)
end

--- Import security findings from SARIF files
---@param options ScrewImportOptions
---@return ScrewImportResult
function M.import_notes(options)
  ensure_initialized()
  local import_module = require("screw.import.init")
  return import_module.import_sarif(options)
end

--- Get plugin statistics
---@return table
function M.get_statistics()
  ensure_initialized()
  local notes_manager = require("screw.notes.manager")
  return notes_manager.get_statistics()
end

--- Debug: Get storage information
---@return table
function M.get_storage_info()
  ensure_initialized()
  local storage = require("screw.notes.storage")
  local stats = storage.get_storage_stats()
  local notes = storage.get_all_notes()
  return {
    stats = stats,
    notes_count = #notes,
    notes = notes,
  }
end

--- Get plugin configuration
---@return screw.InternalConfig
function M.get_config()
  ensure_initialized()
  local config = require("screw.config")
  return config.get()
end

--- Remove duplicate notes (useful after multiple imports)
---@return table result with removed_count and remaining_count
function M.deduplicate_notes()
  ensure_initialized()
  local storage = require("screw.notes.storage")
  local all_notes = storage.get_all_notes()

  local unique_notes = {}
  local seen_ids = {}
  local removed_count = 0

  for _, note in ipairs(all_notes) do
    if seen_ids[note.id] then
      removed_count = removed_count + 1
    else
      seen_ids[note.id] = true
      table.insert(unique_notes, note)
    end
  end

  -- Save deduplicated notes
  storage.replace_all_notes(unique_notes)

  return {
    removed_count = removed_count,
    remaining_count = #unique_notes,
    success = true,
  }
end

--- Jump to next security note in current buffer
---@param opts table? Options table with optional keywords filter
function M.jump_next(opts)
  ensure_initialized()
  local jump = require("screw.jump")
  return jump.jump_next(opts)
end

--- Jump to previous security note in current buffer
---@param opts table? Options table with optional keywords filter
function M.jump_prev(opts)
  ensure_initialized()
  local jump = require("screw.jump")
  return jump.jump_prev(opts)
end

return M
