--- Synchronization module for screw.nvim collaboration
---
--- This module handles operational transformation, conflict resolution,
--- and synchronization of notes between multiple users.
---

local utils = require("screw.utils")

local M = {}

--- Last sync timestamp
M.last_sync = nil

--- Synchronize with remote database
---@param database table Database instance
function M.synchronize(database)
  if not database or not database:is_connected() then
    return
  end

  -- Get changes from database since last sync
  local changes = database:get_changes()

  if #changes > 0 then
    M.apply_changes(changes)
  end

  -- Update last sync timestamp
  M.last_sync = utils.get_timestamp()
end

--- Apply incoming changes and detect conflicts
---@param changes table[] List of changes from other users
---@return table[] List of conflicts
function M.apply_changes(changes)
  local storage = require("screw.notes.storage")
  local conflicts = {}

  -- Group changes by note ID to detect conflicts
  local changes_by_note = {}
  for _, change in ipairs(changes) do
    local note_id = change.note and change.note.id or change.note_id
    if note_id then
      if not changes_by_note[note_id] then
        changes_by_note[note_id] = {}
      end
      table.insert(changes_by_note[note_id], change)
    end
  end

  -- Process changes for each note
  for note_id, note_changes in pairs(changes_by_note) do
    local conflict = M.detect_conflict(note_id, note_changes)

    if conflict then
      table.insert(conflicts, conflict)
    else
      -- Apply changes without conflict
      for _, change in ipairs(note_changes) do
        M.apply_single_change(change, storage)
      end
    end
  end

  return conflicts
end

--- Detect conflicts for a specific note
---@param note_id string
---@param changes table[]
---@return table? Conflict information or nil
function M.detect_conflict(note_id, changes)
  local storage = require("screw.notes.storage")
  local local_note = storage.get_note(note_id)

  if not local_note then
    -- No local note, no conflict
    return nil
  end

  -- Check if there are multiple conflicting changes
  if #changes > 1 then
    return {
      note_id = note_id,
      type = "concurrent_changes",
      changes = changes,
      local_note = local_note,
    }
  end

  local change = changes[1]

  -- Check timestamp-based conflict
  if change.note and change.note.timestamp and local_note.timestamp then
    local remote_time = os.time(os.date("*t", change.note.timestamp))
    local local_time = os.time(os.date("*t", local_note.timestamp))

    -- If local note is newer, there's a conflict
    if local_time > remote_time then
      return {
        note_id = note_id,
        type = "timestamp_conflict",
        changes = changes,
        local_note = local_note,
      }
    end
  end

  return nil
end

--- Apply a single change to local storage
---@param change table
---@param storage table Storage backend
function M.apply_single_change(change, storage)
  if change.action == "create" or change.action == "update" then
    if change.note then
      storage.save_note(change.note)
    end
  elseif change.action == "delete" then
    local note_id = change.note and change.note.id or change.note_id
    if note_id then
      storage.delete_note(note_id)
    end
  end
end

--- Transform operation for conflict resolution
---@param local_op table Local operation
---@param remote_op table Remote operation
---@return table Transformed operation
function M.transform_operation(local_op, remote_op)
  -- Basic operational transformation
  -- This is a simplified implementation

  if local_op.action == "update" and remote_op.action == "update" then
    -- For updates, merge the changes
    local merged_note = utils.deep_copy(local_op.note)

    -- Apply remote changes that don't conflict
    if remote_op.note.comment ~= local_op.note.comment then
      -- Comment conflict - use local version but note the conflict
      merged_note._comment_conflict = {
        local_version = local_op.note.comment,
        remote_version = remote_op.note.comment,
      }
    end

    if remote_op.note.description and not local_op.note.description then
      merged_note.description = remote_op.note.description
    end

    if remote_op.note.cwe and not local_op.note.cwe then
      merged_note.cwe = remote_op.note.cwe
    end

    return {
      action = "update",
      note = merged_note,
      timestamp = utils.get_timestamp(),
    }
  end

  -- For other cases, return local operation unchanged
  return local_op
end

--- Create a change record for broadcasting
---@param note ScrewNote
---@param action string
---@return table Change record
function M.create_change_record(note, action)
  local collaboration = require("screw.collaboration")

  return {
    action = action,
    note = utils.deep_copy(note),
    author = utils.get_author(),
    timestamp = utils.get_timestamp(),
    session_id = collaboration.get_session_id(),
  }
end

--- Get sync statistics
---@return table
function M.get_sync_stats()
  return {
    last_sync = M.last_sync,
    sync_enabled = M.last_sync ~= nil,
  }
end

--- Reset sync state (for testing)
function M.reset()
  M.last_sync = nil
end

return M