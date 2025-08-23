--- Migration utilities for screw.nvim collaboration
---
--- This module provides bidirectional migration between local and PostgreSQL storage.
---

local utils = require("screw.utils")
local _ = require("screw.config") -- config loaded for potential future use

---@class MigrationUtil
local MigrationUtil = {}

--- Progress callback for migration operations
---@class MigrationProgress
---@field total integer Total items to migrate
---@field completed integer Completed items
---@field current_item string? Current item being processed
---@field errors table List of errors encountered

--- Migration statistics
---@class MigrationStats
---@field notes_migrated integer Number of notes migrated
---@field replies_migrated integer Number of replies migrated
---@field errors_count integer Number of errors
---@field start_time number Migration start timestamp
---@field end_time number? Migration end timestamp
---@field duration number? Migration duration in seconds

--- Migrate from local JSON/SQLite storage to PostgreSQL
---@param progress_callback? function Optional progress callback
---@return boolean, string?, MigrationStats Success, error message, statistics
function MigrationUtil.migrate_local_to_db(progress_callback)
  local stats = {
    notes_migrated = 0,
    replies_migrated = 0,
    errors_count = 0,
    start_time = vim.loop.now(),
  }

  -- Initialize PostgreSQL backend
  local PostgreSQLBackend = require("screw.notes.storage.postgresql")
  local pg_backend = PostgreSQLBackend.new({ backend = "postgresql" })

  local success, error_msg = pg_backend:connect()
  if not success then
    return false, "Failed to connect to PostgreSQL: " .. (error_msg or "unknown error"), stats
  end

  -- Load notes from current local backend
  local current_backend = require("screw.notes.storage").get_backend()
  if not current_backend then
    pg_backend:disconnect()
    return false, "No current storage backend found", stats
  end

  -- Get all local notes
  current_backend:load_notes()
  local local_notes = current_backend:get_all_notes()

  if #local_notes == 0 then
    pg_backend:disconnect()
    utils.info("No local notes found to migrate")
    stats.end_time = vim.loop.now()
    stats.duration = (stats.end_time - stats.start_time) / 1000
    return true, nil, stats
  end

  utils.info(string.format("Starting migration of %d notes to PostgreSQL...", #local_notes))

  -- Progress tracking
  local progress = {
    total = #local_notes,
    completed = 0,
    current_item = nil,
    errors = {},
  }

  -- Migrate each note
  for i, note in ipairs(local_notes) do
    progress.current_item = string.format("Note %d/%d: %s:%d", i, #local_notes, note.file_path, note.line_number)
    progress.completed = i - 1

    if progress_callback then
      progress_callback(progress)
    end

    -- Prepare note for PostgreSQL
    local pg_note = vim.deepcopy(note)

    -- Ensure we have required fields
    pg_note.id = pg_note.id or utils.generate_id()
    pg_note.timestamp = pg_note.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")
    pg_note.version = 1

    -- Migrate the note
    local note_success = pg_backend:save_note(pg_note)
    if note_success then
      stats.notes_migrated = stats.notes_migrated + 1

      -- Migrate replies if present
      if pg_note.replies then
        for _, reply in ipairs(pg_note.replies) do
          -- Note: Reply migration would need to be implemented in PostgreSQL backend
          -- For now, replies are included in the note JSON structure
          stats.replies_migrated = stats.replies_migrated + 1
        end
      end
    else
      stats.errors_count = stats.errors_count + 1
      local migrate_error = string.format("Failed to migrate note %s:%d", note.file_path, note.line_number)
      table.insert(progress.errors, migrate_error)
      utils.warn(migrate_error)
    end
  end

  progress.completed = #local_notes
  if progress_callback then
    progress_callback(progress)
  end

  pg_backend:disconnect()

  stats.end_time = vim.loop.now()
  stats.duration = (stats.end_time - stats.start_time) / 1000

  local success_msg = string.format(
    "Migration completed: %d notes migrated in %.2f seconds (%d errors)",
    stats.notes_migrated,
    stats.duration,
    stats.errors_count
  )

  if stats.errors_count > 0 then
    utils.warn(success_msg)
    return false, string.format("%d errors occurred during migration", stats.errors_count), stats
  else
    utils.info(success_msg)
    return true, nil, stats
  end
end

--- Migrate from PostgreSQL to local JSON storage
---@param progress_callback? function Optional progress callback
---@return boolean, string?, MigrationStats Success, error message, statistics
function MigrationUtil.migrate_db_to_local(progress_callback)
  local stats = {
    notes_migrated = 0,
    replies_migrated = 0,
    errors_count = 0,
    start_time = vim.loop.now(),
  }

  -- Initialize PostgreSQL backend
  local PostgreSQLBackend = require("screw.notes.storage.postgresql")
  local pg_backend = PostgreSQLBackend.new({ backend = "postgresql" })

  local success, error_msg = pg_backend:connect()
  if not success then
    return false, "Failed to connect to PostgreSQL: " .. (error_msg or "unknown error"), stats
  end

  -- Get all database notes
  pg_backend:load_notes()
  local db_notes = pg_backend:get_all_notes()

  if #db_notes == 0 then
    pg_backend:disconnect()
    utils.info("No database notes found to migrate")
    stats.end_time = vim.loop.now()
    stats.duration = (stats.end_time - stats.start_time) / 1000
    return true, nil, stats
  end

  utils.info(string.format("Starting export of %d notes from PostgreSQL...", #db_notes))

  -- Initialize local JSON backend
  local JSONBackend = require("screw.notes.storage.json")
  local json_backend = JSONBackend.new({
    backend = "json",
    path = utils.get_project_root(),
    filename = "", -- Auto-generate
    auto_save = true,
  })
  json_backend:setup()

  -- Progress tracking
  local progress = {
    total = #db_notes,
    completed = 0,
    current_item = nil,
    errors = {},
  }

  -- Clear existing local notes to avoid duplicates
  json_backend:clear_notes()

  -- Migrate each note
  for i, note in ipairs(db_notes) do
    progress.current_item = string.format("Note %d/%d: %s:%d", i, #db_notes, note.file_path, note.line_number)
    progress.completed = i - 1

    if progress_callback then
      progress_callback(progress)
    end

    -- Prepare note for local storage
    local local_note = vim.deepcopy(note)

    -- Convert PostgreSQL-specific fields
    local_note.version = nil -- Not used in local storage

    -- Migrate the note
    local note_success = json_backend:save_note(local_note)
    if note_success then
      stats.notes_migrated = stats.notes_migrated + 1

      -- Count replies
      if local_note.replies then
        stats.replies_migrated = stats.replies_migrated + #local_note.replies
      end
    else
      stats.errors_count = stats.errors_count + 1
      local export_error = string.format("Failed to export note %s:%d", note.file_path, note.line_number)
      table.insert(progress.errors, export_error)
      utils.warn(export_error)
    end
  end

  -- Force save all notes
  json_backend:force_save()

  progress.completed = #db_notes
  if progress_callback then
    progress_callback(progress)
  end

  pg_backend:disconnect()

  stats.end_time = vim.loop.now()
  stats.duration = (stats.end_time - stats.start_time) / 1000

  local success_msg = string.format(
    "Export completed: %d notes exported to local storage in %.2f seconds (%d errors)",
    stats.notes_migrated,
    stats.duration,
    stats.errors_count
  )

  if stats.errors_count > 0 then
    utils.warn(success_msg)
    return false, string.format("%d errors occurred during export", stats.errors_count), stats
  else
    utils.info(success_msg)
    return true, nil, stats
  end
end

--- Synchronize notes between local and database (merge both directions)
---@param conflict_strategy "local_wins"|"db_wins"|"newest_wins"|"ask" How to resolve conflicts
---@param progress_callback? function Optional progress callback
---@return boolean, string?, MigrationStats Success, error message, statistics
function MigrationUtil.sync_bidirectional(conflict_strategy, progress_callback)
  conflict_strategy = conflict_strategy or "newest_wins"

  local stats = {
    notes_migrated = 0,
    replies_migrated = 0,
    errors_count = 0,
    start_time = vim.loop.now(),
  }

  -- Initialize both backends
  local PostgreSQLBackend = require("screw.notes.storage.postgresql")
  local pg_backend = PostgreSQLBackend.new({ backend = "postgresql" })

  local success, error_msg = pg_backend:connect()
  if not success then
    return false, "Failed to connect to PostgreSQL: " .. (error_msg or "unknown error"), stats
  end

  local current_backend = require("screw.notes.storage").get_backend()
  if not current_backend then
    pg_backend:disconnect()
    return false, "No current storage backend found", stats
  end

  -- Load notes from both sources
  current_backend:load_notes()
  pg_backend:load_notes()

  local local_notes = current_backend:get_all_notes()
  local db_notes = pg_backend:get_all_notes()

  -- Create lookup maps
  local local_map = {}
  local db_map = {}

  for _, note in ipairs(local_notes) do
    local_map[note.id] = note
  end

  for _, note in ipairs(db_notes) do
    db_map[note.id] = note
  end

  -- Find all unique note IDs
  local all_ids = {}
  for id in pairs(local_map) do
    all_ids[id] = true
  end
  for id in pairs(db_map) do
    all_ids[id] = true
  end

  local total_notes = vim.tbl_count(all_ids)
  utils.info(string.format("Starting bidirectional sync of %d unique notes...", total_notes))

  -- Progress tracking
  local progress = {
    total = total_notes,
    completed = 0,
    current_item = nil,
    errors = {},
  }

  local processed = 0

  -- Process each unique note
  for id in pairs(all_ids) do
    processed = processed + 1
    local local_note = local_map[id]
    local db_note = db_map[id]

    progress.completed = processed - 1
    progress.current_item = string.format("Syncing note %d/%d: %s", processed, total_notes, id:sub(1, 8))

    if progress_callback then
      progress_callback(progress)
    end

    if local_note and db_note then
      -- Conflict resolution needed
      local winning_note = MigrationUtil.resolve_conflict(local_note, db_note, conflict_strategy)

      if winning_note then
        -- Update both backends with winning note
        if winning_note == local_note then
          pg_backend:save_note(local_note)
        else
          current_backend:save_note(db_note)
        end
        stats.notes_migrated = stats.notes_migrated + 1
      else
        stats.errors_count = stats.errors_count + 1
        table.insert(progress.errors, "Conflict resolution failed for note " .. id)
      end
    elseif local_note then
      -- Note exists only locally - copy to database
      local sync_success = pg_backend:save_note(local_note)
      if sync_success then
        stats.notes_migrated = stats.notes_migrated + 1
      else
        stats.errors_count = stats.errors_count + 1
        table.insert(progress.errors, "Failed to sync local note to database: " .. id)
      end
    elseif db_note then
      -- Note exists only in database - copy to local
      local local_success = current_backend:save_note(db_note)
      if local_success then
        stats.notes_migrated = stats.notes_migrated + 1
      else
        stats.errors_count = stats.errors_count + 1
        table.insert(progress.errors, "Failed to sync database note to local: " .. id)
      end
    end
  end

  -- Force save both backends
  current_backend:force_save()
  pg_backend:force_save()

  progress.completed = total_notes
  if progress_callback then
    progress_callback(progress)
  end

  pg_backend:disconnect()

  stats.end_time = vim.loop.now()
  stats.duration = (stats.end_time - stats.start_time) / 1000

  local success_msg = string.format(
    "Bidirectional sync completed: %d notes synchronized in %.2f seconds (%d errors)",
    stats.notes_migrated,
    stats.duration,
    stats.errors_count
  )

  if stats.errors_count > 0 then
    utils.warn(success_msg)
    return false, string.format("%d errors occurred during sync", stats.errors_count), stats
  else
    utils.info(success_msg)
    return true, nil, stats
  end
end

--- Resolve conflict between two notes
---@param local_note ScrewNote Local note
---@param db_note ScrewNote Database note
---@param strategy "local_wins"|"db_wins"|"newest_wins"|"ask" Conflict resolution strategy
---@return ScrewNote? Winning note or nil if unresolved
function MigrationUtil.resolve_conflict(local_note, db_note, strategy)
  if strategy == "local_wins" then
    return local_note
  elseif strategy == "db_wins" then
    return db_note
  elseif strategy == "newest_wins" then
    -- Compare timestamps
    local local_time = local_note.updated_at or local_note.timestamp or "1970-01-01T00:00:00Z"
    local db_time = db_note.updated_at or db_note.timestamp or "1970-01-01T00:00:00Z"

    return (local_time > db_time) and local_note or db_note
  elseif strategy == "ask" then
    -- Present conflict resolution dialog
    return MigrationUtil.ask_conflict_resolution(local_note, db_note)
  end

  return nil
end

--- Ask user to resolve conflict between two notes
---@param local_note ScrewNote Local note
---@param db_note ScrewNote Database note
---@return ScrewNote? User's choice or nil if cancelled
function MigrationUtil.ask_conflict_resolution(local_note, db_note)
  local local_time = local_note.updated_at or local_note.timestamp or "unknown"
  local db_time = db_note.updated_at or db_note.timestamp or "unknown"

  local message = string.format(
    [[
Conflict found for note in %s:%d

Local version:
  Author: %s
  Updated: %s
  Comment: %s

Database version:
  Author: %s
  Updated: %s
  Comment: %s

Which version should be kept?]],
    local_note.file_path,
    local_note.line_number,
    local_note.author,
    local_time,
    local_note.comment:sub(1, 50),
    db_note.author,
    db_time,
    db_note.comment:sub(1, 50)
  )

  local choices = "&Local\n&Database\n&Skip"
  local choice = vim.fn.confirm(message, choices, 1)

  if choice == 1 then
    return local_note
  elseif choice == 2 then
    return db_note
  else
    return nil -- Skip this note
  end
end

--- Validate migration prerequisites
---@param direction "local_to_db"|"db_to_local"|"bidirectional"
---@return boolean, string? Valid or error message
function MigrationUtil.validate_prerequisites(direction)
  if direction == "local_to_db" or direction == "bidirectional" then
    -- Check database connectivity
    local db_url = os.getenv("SCREW_DB_URL")
    if not db_url then
      return false, "SCREW_DB_URL environment variable is required"
    end

    local user_id = os.getenv("SCREW_USER_EMAIL") or os.getenv("SCREW_USER_ID")
    if not user_id then
      return false, "SCREW_USER_EMAIL or SCREW_USER_ID environment variable is required"
    end

    -- Test connection
    local PostgreSQLBackend = require("screw.notes.storage.postgresql")
    local test_backend = PostgreSQLBackend.new({ backend = "postgresql" })

    local success, error_msg = test_backend:connect()
    if not success then
      return false, "Cannot connect to PostgreSQL: " .. (error_msg or "unknown error")
    end

    test_backend:disconnect()
  end

  if direction == "db_to_local" or direction == "bidirectional" then
    -- Check local storage accessibility
    local project_root = utils.get_project_root()
    if not project_root then
      return false, "Cannot determine project root directory"
    end

    -- Check write permissions
    local test_file = project_root .. "/.screw_migration_test"
    local success = pcall(vim.fn.writefile, { "test" }, test_file)
    if success then
      pcall(vim.fn.delete, test_file)
    else
      return false, "No write permission in project directory: " .. project_root
    end
  end

  return true
end

--- Get migration status and statistics
---@return table Status information
function MigrationUtil.get_status()
  local status = {
    prerequisites = {},
    capabilities = {
      local_to_db = false,
      db_to_local = false,
      bidirectional = false,
    },
  }

  -- Check prerequisites for each direction
  local local_to_db_ok, local_to_db_error = MigrationUtil.validate_prerequisites("local_to_db")
  status.prerequisites.local_to_db = { valid = local_to_db_ok, error = local_to_db_error }
  status.capabilities.local_to_db = local_to_db_ok

  local db_to_local_ok, db_to_local_error = MigrationUtil.validate_prerequisites("db_to_local")
  status.prerequisites.db_to_local = { valid = db_to_local_ok, error = db_to_local_error }
  status.capabilities.db_to_local = db_to_local_ok

  status.capabilities.bidirectional = local_to_db_ok and db_to_local_ok

  return status
end

--- Dry run migration (preview without making changes)
---@param direction "local_to_db"|"db_to_local"|"bidirectional"
---@return boolean, string?, table Success, error message, preview data
function MigrationUtil.dry_run(direction)
  local valid, error_msg = MigrationUtil.validate_prerequisites(direction)
  if not valid then
    return false, error_msg, {}
  end

  local preview = {
    notes_to_migrate = 0,
    conflicts_found = 0,
    source_notes = {},
    target_notes = {},
    conflicts = {},
  }

  -- Implementation would analyze what would be migrated without actually doing it
  -- This is a placeholder for the actual dry run logic

  return true, nil, preview
end

return MigrationUtil
