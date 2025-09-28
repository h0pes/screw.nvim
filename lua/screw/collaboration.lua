--- Collaboration module for screw.nvim
---
--- This module handles collaboration features, mode detection, and migration
--- between local and collaborative storage. Supports both HTTP and PostgreSQL backends.
---

local utils = require("screw.utils")
local config = require("screw.config")

local M = {}

--- Collaboration state
local state = {
  initialized = false,
  mode = nil, -- "local" or "collaborative"
  realtime_sync = nil,
  detection_result = nil,
}

--- Initialize collaboration system
function M.setup()
  if state.initialized then
    return
  end

  -- Check if user has explicitly configured collaboration mode
  local collab_config = config.get_option("collaboration")
  local explicit_mode = nil

  if collab_config.enabled then
    explicit_mode = "collaborative"
  elseif collab_config.enabled == false then
    explicit_mode = "local"
  end

  if explicit_mode then
    -- User has explicit configuration - respect it
    state.mode = explicit_mode
    state.detection_result = {
      mode = explicit_mode,
      reason = "explicitly configured by user",
      requires_migration = false,
      local_notes_found = false,
      db_available = (explicit_mode == "collaborative"),
      db_notes_found = false,
      user_choice = explicit_mode,
    }

    -- Apply the explicit mode configuration
    if explicit_mode == "collaborative" then
      local current_config = config.get()
      current_config.storage.backend = "http"
      current_config.collaboration.enabled = true

      -- Set environment-based configuration
      current_config.collaboration.api_url = os.getenv("SCREW_API_URL")
      current_config.collaboration.user_id = os.getenv("SCREW_USER_EMAIL") or os.getenv("SCREW_USER_ID")

      if not current_config.collaboration.api_url then
        utils.error("SCREW_API_URL environment variable is required for collaborative mode")
        return
      end

      if not current_config.collaboration.user_id then
        utils.error("SCREW_USER_EMAIL or SCREW_USER_ID environment variable is required for collaborative mode")
        return
      end
    end

    local mode_msg = string.format("screw.nvim using %s mode (explicitly configured)", explicit_mode)
    utils.info(mode_msg)
  else
    -- No explicit configuration - use mode detection
    local ModeDetector = require("screw.collaboration.mode_detector")
    local detection_result = ModeDetector.detect_mode()

    state.detection_result = detection_result
    state.mode = detection_result.mode

    -- Apply the detected mode
    local success = ModeDetector.apply_mode(detection_result)
    if not success then
      utils.error("Failed to apply collaboration mode: " .. detection_result.mode)
      return
    end
  end

  -- Handle migration if needed
  if state.detection_result.requires_migration then
    local ModeDetector = require("screw.collaboration.mode_detector")
    local migration_success = ModeDetector.handle_migration(state.detection_result)
    if not migration_success then
      utils.error("Migration failed - falling back to local mode")
      ModeDetector.force_mode("local")
      state.mode = "local"
    else
      utils.info("Migration completed successfully")
    end
  end

  -- Initialize real-time sync for collaborative mode
  if state.mode == "collaborative" then
    M.setup_realtime_sync()
  end

  -- Set up collaboration-specific autocommands
  M.setup_autocommands()

  state.initialized = true

  -- Log the result (only if not already logged for explicit config) - DISABLED for cleaner UX
  -- if not explicit_mode then
  --   local mode_msg = string.format("screw.nvim initialized in %s mode", state.mode)
  --   if state.detection_result.reason then
  --     mode_msg = mode_msg .. " (" .. state.detection_result.reason .. ")"
  --   end
  --   utils.info(mode_msg)
  -- end
end

--- Setup real-time synchronization for collaborative mode
function M.setup_realtime_sync()
  if state.mode ~= "collaborative" then
    return
  end

  local storage = require("screw.notes.storage")
  local backend = storage.get_backend()

  if not backend then
    utils.warn("No storage backend available for real-time sync")
    return
  end

  -- HTTP backend supports real-time sync through periodic refresh
  if backend.__class == "HttpBackend" then
    utils.collaboration_status("HTTP collaboration sync enabled")
    -- For HTTP backend, we don't need a separate real-time sync module
    -- The HTTP backend handles synchronization through its load_notes() method
    return
  elseif backend.__class == "PostgreSQLBackend" then
    -- Initialize real-time sync for PostgreSQL backend
    local RealtimeSync = require("screw.collaboration.realtime")
    state.realtime_sync = RealtimeSync.new(backend)
  else
    utils.info("Real-time sync not available for " .. (backend.__class or "unknown") .. " backend")
    return
  end

  -- Only set up callbacks and start sync for PostgreSQL backend
  if state.realtime_sync then
    -- Set up event callbacks
    state.realtime_sync:on("note_created", function(data)
      M.handle_remote_note_change("created", data)
    end)

    state.realtime_sync:on("note_updated", function(data)
      M.handle_remote_note_change("updated", data)
    end)

    state.realtime_sync:on("note_deleted", function(data)
      M.handle_remote_note_change("deleted", data)
    end)

    state.realtime_sync:on("reply_created", function(data)
      M.handle_remote_reply_change("created", data)
    end)

    -- Start real-time sync
    local success, error_msg = state.realtime_sync:start()
    if success then
      utils.info("Real-time collaboration sync started")
    else
      utils.warn("Real-time sync failed to start: " .. (error_msg or "unknown error"))
      -- Continue without real-time sync
    end
  end
end

--- Handle remote note changes from other users
---@param action string Action type: "created", "updated", "deleted"
---@param data table Event data
function M.handle_remote_note_change(action, data)
  -- Show notification to user
  local message = string.format(
    "%s %s a note in %s:%d",
    data.author or "Someone",
    action,
    data.file_path or "unknown file",
    data.line_number or 0
  )

  vim.schedule(function()
    -- Show notification
    vim.notify("🔄 " .. message, vim.log.levels.INFO, {
      title = "screw.nvim collaboration",
      timeout = 3000,
    })

    -- Update signs if the file is currently open
    M.refresh_current_buffer_if_matches(data.file_path)
  end)
end

--- Handle remote reply changes from other users
---@param action string Action type: "created", "updated", "deleted"
---@param data table Event data
function M.handle_remote_reply_change(action, data)
  local message = string.format("%s %s a reply", data.author or "Someone", action)

  vim.schedule(function()
    vim.notify("💬 " .. message, vim.log.levels.INFO, {
      title = "screw.nvim collaboration",
      timeout = 2000,
    })

    -- Refresh the parent note's file if open
    if data.parent_note then
      M.refresh_current_buffer_if_matches(data.parent_note.file_path)
    end
  end)
end

--- Refresh current buffer if it matches the given file path
---@param file_path string? File path to check
function M.refresh_current_buffer_if_matches(file_path)
  if not file_path then
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(current_buf)
  local current_relative = utils.get_relative_path(current_file)

  if current_relative == file_path then
    -- Trigger signs refresh for current buffer
    vim.api.nvim_exec_autocmds("User", {
      pattern = "ScrewNotesChanged",
      data = {
        buffer = current_buf,
        file_path = file_path,
        action = "collaboration_sync",
      },
    })
  end
end

--- Setup collaboration-specific autocommands
function M.setup_autocommands()
  local augroup = vim.api.nvim_create_augroup("ScrewCollaboration", { clear = true })

  -- Handle buffer enter to sync notes for newly opened files
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(args)
      if state.mode == "collaborative" and state.realtime_sync then
        -- Force a sync check when opening buffers in collaborative mode
        vim.defer_fn(function()
          local file_path = utils.get_relative_path(vim.api.nvim_buf_get_name(args.buf))
          if file_path then
            -- This would trigger a file-specific sync if needed
            -- For now, we rely on the periodic sync
            vim.notify("File change detected: " .. file_path, vim.log.levels.DEBUG)
          end
        end, 1000)
      end
    end,
  })

  -- Handle connection loss recovery
  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    callback = function()
      if state.mode == "collaborative" and state.realtime_sync then
        -- Check if we need to reconnect after losing focus
        M.check_connection_health()
      end
    end,
  })
end

--- Check and restore connection health
function M.check_connection_health()
  if not state.realtime_sync then
    return
  end

  local status = state.realtime_sync:get_status()
  if not status.is_listening then
    utils.warn("Real-time sync connection lost, attempting to reconnect...")

    vim.defer_fn(function()
      local success, error_msg = state.realtime_sync:start()
      if success then
        utils.success("Real-time sync reconnected successfully")
      else
        utils.error("Failed to reconnect real-time sync: " .. (error_msg or "unknown error"))
      end
    end, 2000)
  end
end

--- Get current collaboration status
---@return table Status information
function M.get_status()
  local status = {
    initialized = state.initialized,
    mode = state.mode,
    detection_result = state.detection_result,
    realtime_sync = nil,
  }

  if state.realtime_sync then
    status.realtime_sync = state.realtime_sync:get_status()
  end

  return status
end

--- Switch collaboration mode (with user confirmation)
---@param new_mode "local"|"collaborative" Target mode
---@param force? boolean Skip confirmation
---@return boolean Success
function M.switch_mode(new_mode, force)
  if state.mode == new_mode then
    utils.info("Already in " .. new_mode .. " mode")
    return true
  end

  if not force then
    local confirm_msg =
      string.format("Switch from %s to %s mode?\nThis may require data migration.", state.mode, new_mode)

    local choice = vim.fn.confirm(confirm_msg, "&Yes\n&No", 2)
    if choice ~= 1 then
      return false
    end
  end

  -- Stop current collaboration features
  M.cleanup()

  -- Apply new mode
  local ModeDetector = require("screw.collaboration.mode_detector")
  local success = ModeDetector.force_mode(new_mode)

  if not success then
    utils.error("Failed to switch to " .. new_mode .. " mode")
    return false
  end

  -- Reinitialize with new mode
  state.initialized = false
  state.mode = new_mode
  M.setup()

  utils.info("Switched to " .. new_mode .. " mode successfully")
  return true
end

--- Trigger manual synchronization (for collaborative mode)
---@return boolean Success
function M.sync_now()
  if state.mode ~= "collaborative" then
    utils.warn("Manual sync is only available in collaborative mode")
    return false
  end

  local storage = require("screw.notes.storage")
  local backend = storage.get_backend()

  if backend and backend.load_notes then
    backend:load_notes()
    utils.info("Manual sync completed")

    -- Refresh all open buffers with notes
    M.refresh_all_buffers_with_notes()

    return true
  else
    utils.error("Backend does not support manual sync")
    return false
  end
end

--- Refresh all open buffers that contain notes
function M.refresh_all_buffers_with_notes()
  local storage = require("screw.notes.storage")
  local all_notes = storage.get_all_notes()

  -- Get unique file paths with notes
  local files_with_notes = {}
  for _, note in ipairs(all_notes) do
    files_with_notes[note.file_path] = true
  end

  -- Check all open buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local relative_path = utils.get_relative_path(buf_name)

      if files_with_notes[relative_path] then
        vim.api.nvim_exec_autocmds("User", {
          pattern = "ScrewNotesChanged",
          data = {
            buffer = buf,
            file_path = relative_path,
            action = "manual_sync",
          },
        })
      end
    end
  end
end

--- Show collaboration info to user
function M.show_info()
  local status = M.get_status()
  local lines = {}

  table.insert(lines, "=== screw.nvim Collaboration Status ===")
  table.insert(lines, "")
  table.insert(lines, "Mode: " .. (status.mode or "unknown"))
  table.insert(lines, "Initialized: " .. tostring(status.initialized))

  if status.detection_result then
    table.insert(lines, "Detection reason: " .. (status.detection_result.reason or "unknown"))
    table.insert(lines, "Local notes found: " .. tostring(status.detection_result.local_notes_found))
    table.insert(lines, "Database available: " .. tostring(status.detection_result.db_available))
    table.insert(lines, "Database notes found: " .. tostring(status.detection_result.db_notes_found))
  end

  if status.realtime_sync then
    table.insert(lines, "")
    table.insert(lines, "Real-time sync:")
    table.insert(lines, "  Listening: " .. tostring(status.realtime_sync.is_listening))
    table.insert(lines, "  Supported: " .. tostring(status.realtime_sync.is_supported))
    if not status.realtime_sync.is_supported then
      table.insert(lines, "  Reason: " .. (status.realtime_sync.support_reason or "unknown"))
    end
  end

  -- Show storage stats
  local storage = require("screw.notes.storage")
  local storage_stats = storage.get_storage_stats()
  table.insert(lines, "")
  table.insert(lines, "Storage stats:")
  table.insert(lines, "  Backend: " .. (storage_stats.backend or "unknown"))
  table.insert(lines, "  Notes count: " .. (storage_stats.notes_count or 0))
  if storage_stats.user_id then
    table.insert(lines, "  User ID: " .. storage_stats.user_id)
  end

  -- Display in a popup
  vim.schedule(function()
    local content = table.concat(lines, "\n")
    vim.notify(content, vim.log.levels.INFO, {
      title = "screw.nvim Collaboration",
      timeout = false, -- Don't auto-dismiss
    })
  end)
end

--- Access migration utilities
---@return table Migration utility functions
function M.migration()
  return require("screw.collaboration.migration")
end

--- Cleanup collaboration features
function M.cleanup()
  if state.realtime_sync then
    state.realtime_sync:stop()
    state.realtime_sync = nil
  end

  -- Clear autocommands
  pcall(vim.api.nvim_del_augroup_by_name, "ScrewCollaboration")
end

return M
