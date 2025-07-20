--- Storage backend factory for screw.nvim
---
--- This module manages storage backends and provides a unified interface.
---

local config = require("screw.config")
local utils = require("screw.utils")

local M = {}

--- Current storage backend instance
M.backend = nil

--- Initialize storage backend based on configuration
function M.setup()
  -- Reset backend to ensure fresh initialization
  M.backend = nil

  local storage_config = config.get_option("storage")
  if not storage_config then
    utils.error("Storage configuration not found")
    return
  end

  local backend_type = storage_config.backend or "json"
  local backend_module = "screw.notes.storage." .. backend_type

  local has_backend, backend_class = pcall(require, backend_module)
  if not has_backend then
    utils.error("Failed to load storage backend: " .. backend_type)
    return
  end

  M.backend = backend_class.new(storage_config)
  M.backend:setup()
end

--- Get the current storage backend
---@return StorageBackend
function M.get_backend()
  if not M.backend then
    M.setup()
  end
  return M.backend
end

--- Delegate all storage operations to the current backend
function M.load_notes()
  return M.get_backend():load_notes()
end

function M.save_notes()
  return M.get_backend():save_notes()
end

function M.get_all_notes()
  return M.get_backend():get_all_notes()
end

function M.get_note(id)
  return M.get_backend():get_note(id)
end

function M.save_note(note)
  return M.get_backend():save_note(note)
end

function M.delete_note(id)
  return M.get_backend():delete_note(id)
end

function M.get_notes_for_file(file_path)
  return M.get_backend():get_notes_for_file(file_path)
end

function M.get_notes_for_line(file_path, line_number)
  return M.get_backend():get_notes_for_line(file_path, line_number)
end

function M.clear_notes()
  return M.get_backend():clear_notes()
end

function M.force_save()
  return M.get_backend():force_save()
end

function M.get_storage_stats()
  return M.get_backend():get_storage_stats()
end

function M.replace_all_notes(notes)
  return M.get_backend():replace_all_notes(notes)
end

return M
