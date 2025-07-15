--- Collaboration module for screw.nvim
---
--- This module handles real-time collaboration features including database
--- synchronization, conflict resolution, and multi-user support.
---

local config = require("screw.config")
local utils = require("screw.utils")

local M = {}

--- Current collaboration state
M.enabled = false
M.database = nil
M.sync_timer = nil
M.connected_users = {}

--- Initialize collaboration module
function M.setup()
  local collab_config = config.get_option("collaboration")
  if not collab_config or not collab_config.enabled then
    return
  end

  M.enabled = true

  if not collab_config.database_url then
    utils.error("Collaboration enabled but no database URL configured")
    return
  end

  -- Initialize database connection
  local database = require("screw.collaboration.database")
  M.database = database.new(collab_config)

  if not M.database:connect() then
    utils.error("Failed to connect to collaboration database")
    M.enabled = false
    return
  end

  -- Start sync process
  M.start_sync()

  utils.info("Collaboration mode enabled")
end

--- Start synchronization process
function M.start_sync()
  if not M.enabled or M.sync_timer then
    return
  end

  local sync_interval = config.get_option("collaboration.sync_interval") or 1000
  local sync = require("screw.collaboration.sync")

  M.sync_timer = vim.loop.new_timer()
  M.sync_timer:start(0, sync_interval, vim.schedule_wrap(function()
    if M.enabled and M.database then
      sync.synchronize(M.database)
    end
  end))
end

--- Stop synchronization process
function M.stop_sync()
  if M.sync_timer then
    M.sync_timer:stop()
    M.sync_timer:close()
    M.sync_timer = nil
  end
end

--- Disconnect from collaboration
function M.disconnect()
  M.stop_sync()

  if M.database then
    M.database:disconnect()
    M.database = nil
  end

  M.enabled = false
  M.connected_users = {}

  utils.info("Disconnected from collaboration")
end

--- Get collaboration status
---@return table
function M.get_status()
  return {
    enabled = M.enabled,
    connected = M.database and M.database:is_connected() or false,
    users = vim.tbl_keys(M.connected_users),
    sync_active = M.sync_timer ~= nil,
  }
end

--- Broadcast note change to other users
---@param note ScrewNote
---@param action string
function M.broadcast_note_change(note, action)
  if not M.enabled or not M.database then
    return
  end

  local change = {
    action = action, -- "create", "update", "delete"
    note = note,
    author = utils.get_author(),
    timestamp = utils.get_timestamp(),
    session_id = M.get_session_id(),
  }

  M.database:broadcast_change(change)
end

--- Get current session ID
---@return string
function M.get_session_id()
  if not M.session_id then
    M.session_id = utils.generate_id()
  end
  return M.session_id
end

--- Handle incoming note changes from other users
---@param changes table[]
function M.handle_incoming_changes(changes)
  if not changes or #changes == 0 then
    return
  end

  local sync = require("screw.collaboration.sync")
  local conflicts = sync.apply_changes(changes)

  if #conflicts > 0 then
    M.handle_conflicts(conflicts)
  end

  -- Emit events for UI updates
  local events = require("screw.events")
  events.emit("collaboration:changes_applied", { changes = changes, conflicts = conflicts })
end

--- Handle synchronization conflicts
---@param conflicts table[]
function M.handle_conflicts(conflicts)
  utils.warn(string.format("Detected %d synchronization conflicts", #conflicts))

  for _, conflict in ipairs(conflicts) do
    -- For now, use simple last-writer-wins strategy
    -- TODO: Implement more sophisticated conflict resolution
    local resolution = M.resolve_conflict_simple(conflict)

    if resolution then
      local storage = require("screw.notes.storage")
      storage.save_note(resolution.note)

      utils.info(string.format("Resolved conflict for note %s using %s strategy",
        conflict.note_id, resolution.strategy))
    end
  end
end

--- Simple conflict resolution using last-writer-wins
---@param conflict table
---@return table?
function M.resolve_conflict_simple(conflict)
  -- Choose the change with the latest timestamp
  local latest_change = conflict.changes[1]

  for _, change in ipairs(conflict.changes) do
    if change.timestamp > latest_change.timestamp then
      latest_change = change
    end
  end

  return {
    note = latest_change.note,
    strategy = "last_writer_wins",
  }
end

--- Update user presence
---@param user_info table
function M.update_user_presence(user_info)
  M.connected_users[user_info.id] = {
    name = user_info.name,
    last_seen = utils.get_timestamp(),
    cursor_position = user_info.cursor_position,
  }

  -- Emit presence update event
  local events = require("screw.events")
  events.emit("collaboration:user_presence", { user = user_info })
end

--- Get list of connected users
---@return table[]
function M.get_connected_users()
  local users = {}
  local current_time = os.time()

  for id, user in pairs(M.connected_users) do
    -- Consider user disconnected if not seen for 30 seconds
    local last_seen_time = os.time(os.date("*t", user.last_seen))
    if current_time - last_seen_time < 30 then
      table.insert(users, {
        id = id,
        name = user.name,
        last_seen = user.last_seen,
        cursor_position = user.cursor_position,
      })
    else
      -- Remove disconnected user
      M.connected_users[id] = nil
    end
  end

  return users
end

--- Clean up collaboration module
function M.cleanup()
  M.disconnect()
end

return M