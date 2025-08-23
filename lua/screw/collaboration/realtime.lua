--- Real-time synchronization for PostgreSQL collaboration
---
--- This module handles PostgreSQL LISTEN/NOTIFY for real-time note synchronization
--- across multiple screw.nvim instances.
---

local utils = require("screw.utils")

---@class RealtimeSync
local RealtimeSync = {}
RealtimeSync.__index = RealtimeSync

--- Notification channels
local CHANNELS = {
  NOTES = "screw_notes_changes",
  REPLIES = "screw_replies_changes",
}

--- Create new real-time sync instance
---@param backend PostgreSQLBackend Storage backend
---@return RealtimeSync
function RealtimeSync.new(backend)
  local self = setmetatable({}, RealtimeSync)

  self.backend = backend
  self.is_listening = false
  self.notification_timer = nil
  self.callbacks = {
    note_created = {},
    note_updated = {},
    note_deleted = {},
    reply_created = {},
    reply_updated = {},
    reply_deleted = {},
  }

  return self
end

--- Add event callback
---@param event string Event name
---@param callback function Event handler
function RealtimeSync:on(event, callback)
  if self.callbacks[event] then
    table.insert(self.callbacks[event], callback)
  end
end

--- Emit event to all callbacks
---@param event string Event name
---@param data table Event data
function RealtimeSync:emit(event, data)
  if self.callbacks[event] then
    for _, callback in ipairs(self.callbacks[event]) do
      pcall(callback, data)
    end
  end
end

--- Start listening for PostgreSQL notifications
---@return boolean, string? Success or error message
function RealtimeSync:start()
  if self.is_listening then
    return true
  end

  if not self.backend.connection.is_connected then
    return false, "Database connection required for real-time sync"
  end

  -- Start listening to channels
  local success, error_msg = self:subscribe_to_channels()
  if not success then
    return false, error_msg
  end

  -- Start notification polling
  self:start_notification_polling()

  self.is_listening = true
  utils.info("Real-time sync started for project: " .. (self.backend.connection.project_name or "unknown"))

  return true
end

--- Stop listening for notifications
function RealtimeSync:stop()
  if not self.is_listening then
    return
  end

  -- Stop notification polling
  if self.notification_timer then
    self.notification_timer:stop()
    self.notification_timer:close()
    self.notification_timer = nil
  end

  -- Unsubscribe from channels
  self:unsubscribe_from_channels()

  self.is_listening = false
  utils.info("Real-time sync stopped")
end

--- Subscribe to PostgreSQL notification channels
---@return boolean, string? Success or error message
function RealtimeSync:subscribe_to_channels()
  local queries = {
    "LISTEN " .. CHANNELS.NOTES,
    "LISTEN " .. CHANNELS.REPLIES,
  }

  for _, query in ipairs(queries) do
    local result, error_msg = self.backend:execute_query(query)
    if not result then
      return false, "Failed to listen to channel: " .. error_msg
    end
  end

  return true
end

--- Unsubscribe from PostgreSQL notification channels
function RealtimeSync:unsubscribe_from_channels()
  local queries = {
    "UNLISTEN " .. CHANNELS.NOTES,
    "UNLISTEN " .. CHANNELS.REPLIES,
  }

  for _, query in ipairs(queries) do
    pcall(function()
      self.backend:execute_query(query)
    end)
  end
end

--- Start polling for notifications
function RealtimeSync:start_notification_polling()
  if self.notification_timer then
    return
  end

  self.notification_timer = vim.loop.new_timer()
  if not self.notification_timer then
    return
  end

  -- Poll every 1 second for notifications
  self.notification_timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      self:check_notifications()
    end)
  )
end

--- Check for pending notifications
function RealtimeSync:check_notifications()
  if not self.backend.connection.is_connected then
    return
  end

  local handle = self.backend.connection.handle
  if not handle then
    return
  end

  -- Different notification checking based on PostgreSQL module
  local notifications = {}

  if handle.get_notifications then
    -- pgmoon style
    notifications = handle:get_notifications() or {}
  elseif handle.consume_notifications then
    -- Alternative API
    notifications = handle:consume_notifications() or {}
  else
    -- Fallback: use a simple query approach
    self:fallback_sync_check()
    return
  end

  -- Process notifications
  for _, notification in ipairs(notifications) do
    self:process_notification(notification)
  end
end

--- Process a single notification
---@param notification table Notification data
function RealtimeSync:process_notification(notification)
  if not notification.channel or not notification.payload then
    return
  end

  local success, data = pcall(vim.json.decode, notification.payload)
  if not success then
    utils.warn("Failed to parse notification payload: " .. notification.payload)
    return
  end

  -- Only process notifications for our project
  if data.project_name and data.project_name ~= self.backend.connection.project_name then
    return
  end

  -- Don't process our own changes
  if data.author and data.author == self.backend.connection.user_id then
    return
  end

  if notification.channel == CHANNELS.NOTES then
    self:handle_note_notification(data)
  elseif notification.channel == CHANNELS.REPLIES then
    self:handle_reply_notification(data)
  end
end

--- Handle note change notification
---@param data table Notification data
function RealtimeSync:handle_note_notification(data)
  local action = data.action
  local note_id = data.note_id

  if action == "create" then
    -- Reload the specific note from database
    local note = self:fetch_note_by_id(note_id)
    if note then
      self.backend.cache.notes[note_id] = note
      self:emit("note_created", {
        note = note,
        author = data.author,
        file_path = data.file_path,
        line_number = data.line_number,
      })

      -- Refresh UI for the affected file
      self:refresh_file_ui(data.file_path)
    end
  elseif action == "update" then
    -- Reload the updated note
    local note = self:fetch_note_by_id(note_id)
    if note then
      local old_note = self.backend.cache.notes[note_id]
      self.backend.cache.notes[note_id] = note
      self:emit("note_updated", {
        note = note,
        old_note = old_note,
        author = data.author,
        version = data.version,
      })

      -- Refresh UI for the affected file
      self:refresh_file_ui(data.file_path)
    end
  elseif action == "delete" then
    -- Remove from cache
    local old_note = self.backend.cache.notes[note_id]
    if old_note then
      self.backend.cache.notes[note_id] = nil
      self:emit("note_deleted", {
        note_id = note_id,
        old_note = old_note,
        author = data.author,
        file_path = data.file_path,
        line_number = data.line_number,
      })

      -- Refresh UI for the affected file
      self:refresh_file_ui(data.file_path)
    end
  end
end

--- Handle reply change notification
---@param data table Notification data
function RealtimeSync:handle_reply_notification(data)
  local action = data.action
  local reply_id = data.reply_id
  local parent_id = data.parent_id

  -- Find the parent note
  local parent_note = self.backend.cache.notes[parent_id]
  if not parent_note then
    return
  end

  if action == "reply_create" then
    -- Fetch the new reply
    local reply = self:fetch_reply_by_id(reply_id)
    if reply then
      parent_note.replies = parent_note.replies or {}
      table.insert(parent_note.replies, reply)

      self:emit("reply_created", {
        reply = reply,
        parent_note = parent_note,
        author = data.author,
      })

      -- Refresh UI for the affected file
      self:refresh_file_ui(parent_note.file_path)
    end
  elseif action == "reply_update" then
    -- Update existing reply
    local reply = self:fetch_reply_by_id(reply_id)
    if reply and parent_note.replies then
      for i, existing_reply in ipairs(parent_note.replies) do
        if existing_reply.id == reply_id then
          local old_reply = existing_reply
          parent_note.replies[i] = reply

          self:emit("reply_updated", {
            reply = reply,
            old_reply = old_reply,
            parent_note = parent_note,
            author = data.author,
          })
          break
        end
      end
    end
  elseif action == "reply_delete" then
    -- Remove reply from parent note
    if parent_note.replies then
      for i, existing_reply in ipairs(parent_note.replies) do
        if existing_reply.id == reply_id then
          local old_reply = table.remove(parent_note.replies, i)

          self:emit("reply_deleted", {
            reply_id = reply_id,
            old_reply = old_reply,
            parent_note = parent_note,
            author = data.author,
          })
          break
        end
      end
    end
  end
end

--- Fetch a single note by ID from database
---@param note_id string Note ID
---@return ScrewNote?
function RealtimeSync:fetch_note_by_id(note_id)
  local query = [[
    SELECT n.*, 
           (SELECT json_agg(
              json_build_object(
                'id', r.id,
                'parent_id', r.parent_id,
                'author', r.author,
                'timestamp', r.timestamp,
                'comment', r.comment
              ) ORDER BY r.created_at
            ) FROM replies r WHERE r.parent_id = n.id) as replies
    FROM notes n 
    WHERE n.id = $1 AND n.project_id = $2
  ]]

  local result, error_msg = self.backend:execute_query(query, { note_id, self.backend.connection.project_id })
  if result and result[1] then
    return self.backend:row_to_note(result[1])
  end

  return nil
end

--- Fetch a single reply by ID from database
---@param reply_id string Reply ID
---@return ScrewReply?
function RealtimeSync:fetch_reply_by_id(reply_id)
  local query = "SELECT * FROM replies WHERE id = $1"

  local result, error_msg = self.backend:execute_query(query, { reply_id })
  if result and result[1] then
    local row = result[1]
    return {
      id = row.id,
      parent_id = row.parent_id,
      author = row.author,
      timestamp = row.timestamp,
      comment = row.comment,
    }
  end

  return nil
end

--- Refresh UI for a specific file
---@param file_path string File path to refresh
function RealtimeSync:refresh_file_ui(file_path)
  vim.schedule(function()
    -- Find buffers with this file path and refresh signs/highlights
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        local relative_path = utils.get_relative_path(buf_name)

        if relative_path == file_path then
          -- Trigger a refresh of the signs for this buffer
          -- This would normally call the signs module to update
          vim.api.nvim_exec_autocmds("User", {
            pattern = "ScrewNotesChanged",
            data = {
              buffer = buf,
              file_path = file_path,
              action = "sync_update",
            },
          })
        end
      end
    end
  end)
end

--- Fallback sync check when LISTEN/NOTIFY is not available
function RealtimeSync:fallback_sync_check()
  -- Simple timestamp-based sync check
  -- This is less efficient but works when LISTEN/NOTIFY is not supported

  local query = [[
    SELECT MAX(updated_at) as last_update
    FROM notes 
    WHERE project_id = $1 AND updated_at > $2
  ]]

  local last_sync = self.backend.cache.last_sync or 0
  local last_sync_timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", last_sync / 1000)

  local result, error_msg = self.backend:execute_query(query, {
    self.backend.connection.project_id,
    last_sync_timestamp,
  })

  if result and result[1] and result[1].last_update then
    -- There are updates since last sync - reload all notes
    self.backend:load_notes()

    -- Emit a general sync update event
    self:emit("sync_update", {
      last_update = result[1].last_update,
      sync_timestamp = vim.loop.now(),
    })
  end
end

--- Check if real-time sync is supported
---@return boolean, string? Supported or reason why not
function RealtimeSync:is_supported()
  if not self.backend.connection.is_connected then
    return false, "Database connection required"
  end

  local handle = self.backend.connection.handle
  if not handle then
    return false, "No database handle available"
  end

  -- Check if the handle supports notifications
  if handle.get_notifications or handle.consume_notifications then
    return true, nil
  else
    return false, "PostgreSQL module does not support LISTEN/NOTIFY - using fallback polling"
  end
end

--- Get sync status information
---@return table Status information
function RealtimeSync:get_status()
  local supported, reason = self:is_supported()

  return {
    is_listening = self.is_listening,
    is_supported = supported,
    support_reason = reason,
    channels = CHANNELS,
    project_name = self.backend.connection.project_name,
    callbacks_registered = vim.tbl_count(self.callbacks),
  }
end

return RealtimeSync
