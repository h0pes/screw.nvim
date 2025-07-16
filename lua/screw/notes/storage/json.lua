--- JSON storage backend for screw.nvim
---
--- This module implements the StorageBackend interface using JSON files.
---

local utils = require("screw.utils")

local M = {}

--- Create a new JSON storage backend
---@param config table Storage configuration
---@return StorageBackend
function M.new(config)
  local backend = {}

  backend.storage_path = nil
  backend.notes = {}
  backend.config = config

  --- Initialize storage
  function backend:setup()
    -- Reset storage path to ensure fresh discovery
    self.storage_path = nil
    self:load_notes()
  end

  --- Get the current storage path (resolved dynamically)
  function backend:get_storage_path()
    if not self.storage_path then
      -- Build full storage path from directory and filename
      -- Always resolve to current project root
      local utils = require("screw.utils")
      local storage_dir = utils.get_project_root()
      utils.ensure_dir(storage_dir)

      local filename
      if self.config.filename and self.config.filename ~= "" then
        -- User provided a specific filename
        filename = self.config.filename
      else
        -- Look for existing screw notes files in the project root
        filename = self:find_existing_notes_file(storage_dir)
        if not filename then
          -- No existing file found, create a new one with timestamp
          filename = "screw_notes_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
        end
      end

      self.storage_path = storage_dir .. "/" .. filename
    end
    return self.storage_path
  end

  --- Find existing notes files in the project directory
  ---@param storage_dir string
  ---@return string? filename
  function backend:find_existing_notes_file(storage_dir)
    -- local utils = require("screw.utils")

    -- Use vim.fn.glob to find all screw_notes_*.json files
    local glob_pattern = storage_dir .. "/screw_notes_*.json"
    local files = vim.fn.glob(glob_pattern, false, true)

    if type(files) == "table" and #files > 0 then
      -- Sort files by modification time (newest first)
      table.sort(files, function(a, b)
        local stat_a = vim.loop.fs_stat(a)
        local stat_b = vim.loop.fs_stat(b)
        if stat_a and stat_b then
          return stat_a.mtime.sec > stat_b.mtime.sec
        end
        return false
      end)

      -- Return the most recently modified file (just the filename, not full path)
      local full_path = files[1]
      local filename = vim.fn.fnamemodify(full_path, ":t")
      -- utils.info("Found existing notes file: " .. filename)
      return filename
    end

    -- utils.info("No existing notes files found in " .. storage_dir)
    return nil
  end

  --- Load notes from storage
  function backend:load_notes()
    local storage_path = self:get_storage_path()
    if not storage_path then
      utils.info("No storage path available")
      return
    end

    if not utils.file_exists(storage_path) then
      -- utils.info("Notes file does not exist: " .. storage_path)
      self.notes = {}
      return
    end

    local content = utils.read_file(storage_path)
    if not content then
      utils.error("Failed to read notes file: " .. storage_path)
      return
    end

    local success, data = pcall(vim.json.decode, content)
    if not success then
      utils.error("Failed to parse notes file: " .. data)
      return
    end

    if type(data) == "table" and data.notes then
      self.notes = data.notes
      utils.info("Loaded " .. #self.notes .. " notes from " .. storage_path)
    else
      self.notes = {}
      utils.info("No notes found in file: " .. storage_path)
    end
  end

  --- Save notes to storage
  ---@return boolean
  function backend:save_notes()
    local storage_path = self:get_storage_path()
    if not storage_path then
      return false
    end

    local data = {
      version = "1.0",
      notes = self.notes,
      metadata = {
        created_at = utils.get_timestamp(),
        total_notes = #self.notes,
      },
    }

    local success, json_str = pcall(vim.json.encode, data)
    if not success then
      utils.error("Failed to encode notes: " .. json_str)
      return false
    end

    if utils.write_file(storage_path, json_str) then
      return true
    else
      utils.error("Failed to write notes file")
      return false
    end
  end

  --- Get all notes
  ---@return ScrewNote[]
  function backend:get_all_notes()
    return self.notes
  end

  --- Get note by ID
  ---@param id string
  ---@return ScrewNote?
  function backend:get_note(id)
    for _, note in ipairs(self.notes) do
      if note.id == id then
        return utils.deep_copy(note)
      end
    end
    return nil
  end

  --- Save a note (create or update)
  ---@param note ScrewNote
  ---@return boolean
  function backend:save_note(note)
    if not note or not note.id then
      return false
    end

    -- Find existing note
    local found_index = nil
    for i, existing_note in ipairs(self.notes) do
      if existing_note.id == note.id then
        found_index = i
        break
      end
    end

    if found_index then
      -- Update existing note
      self.notes[found_index] = utils.deep_copy(note)
    else
      -- Add new note
      table.insert(self.notes, utils.deep_copy(note))
    end

    -- Auto-save if enabled
    if self.config.auto_save then
      return self:save_notes()
    end

    return true
  end

  --- Delete a note
  ---@param id string
  ---@return boolean
  function backend:delete_note(id)
    local found_index = nil
    for i, note in ipairs(self.notes) do
      if note.id == id then
        found_index = i
        break
      end
    end

    if found_index then
      table.remove(self.notes, found_index)

      -- Auto-save if enabled
      if self.config.auto_save then
        return self:save_notes()
      end

      return true
    end

    return false
  end

  --- Get notes for a specific file
  ---@param file_path string
  ---@return ScrewNote[]
  function backend:get_notes_for_file(file_path)
    local file_notes = {}
    for _, note in ipairs(self.notes) do
      if note.file_path == file_path then
        table.insert(file_notes, utils.deep_copy(note))
      end
    end
    return file_notes
  end

  --- Get notes for a specific line
  ---@param file_path string
  ---@param line_number number
  ---@return ScrewNote[]
  function backend:get_notes_for_line(file_path, line_number)
    local line_notes = {}
    for _, note in ipairs(self.notes) do
      if note.file_path == file_path and note.line_number == line_number then
        table.insert(line_notes, utils.deep_copy(note))
      end
    end
    return line_notes
  end

  --- Clear all notes (for testing)
  function backend:clear_notes()
    self.notes = {}
  end

  --- Force save notes
  ---@return boolean
  function backend:force_save()
    return self:save_notes()
  end

  --- Get storage statistics
  ---@return table
  function backend:get_storage_stats()
    local storage_path = self:get_storage_path()
    local stats = {
      total_notes = #self.notes,
      storage_path = storage_path,
      file_exists = utils.file_exists(storage_path or ""),
      auto_save = self.config.auto_save,
      backend_type = "json",
    }

    if stats.file_exists then
      local content = utils.read_file(storage_path)
      stats.file_size = content and #content or 0
    end

    return stats
  end

  return backend
end

return M
