--- PostgreSQL storage backend for screw.nvim collaboration
---
--- This module provides PostgreSQL-based storage for multi-user collaboration.
--- It implements the StorageBackend interface and supports real-time synchronization.
---

local utils = require("screw.utils")
local config = require("screw.config")

---@class PostgreSQLBackend : StorageBackend
local PostgreSQLBackend = {}
PostgreSQLBackend.__index = PostgreSQLBackend

--- PostgreSQL connection and state management
---@class PostgreSQLConnection
---@field handle userdata? Database connection handle
---@field url string Connection URL
---@field project_id integer? Current project ID
---@field project_name string? Current project name
---@field user_id string User identifier for collaboration
---@field is_connected boolean Connection status
---@field last_error string? Last error message
---@field retry_count integer Connection retry counter

--- Notes cache for performance
---@class NotesCache
---@field notes table<string, ScrewNote> Notes by ID
---@field dirty boolean Cache needs sync
---@field last_sync number Last sync timestamp

--- Real-time sync state
---@class SyncState
---@field enabled boolean Real-time sync active
---@field listening boolean Currently listening for notifications
---@field timer userdata? Sync timer handle
---@field callbacks table<string, function> Event callbacks

--- Offline mode state
---@class OfflineState
---@field active boolean Currently in offline mode
---@field queued_operations table[] Operations queued for when online
---@field last_connection_attempt number Last attempt timestamp
---@field connection_retry_delay number Current retry delay (exponential backoff)

--- Create new PostgreSQL backend instance
---@param storage_config table Storage configuration
---@return PostgreSQLBackend
function PostgreSQLBackend.new(storage_config)
  local self = setmetatable({}, PostgreSQLBackend)

  -- Configuration
  self.config = storage_config or {}
  self.collaboration_config = config.get_option("collaboration") or {}

  -- Connection management
  self.connection = {
    handle = nil,
    url = nil,
    project_id = nil,
    project_name = nil,
    user_id = nil,
    is_connected = false,
    last_error = nil,
    retry_count = 0,
  }

  -- Notes cache
  self.cache = {
    notes = {},
    dirty = false,
    last_sync = 0,
  }

  -- Real-time sync
  self.sync = {
    enabled = false,
    listening = false,
    timer = nil,
    callbacks = {},
  }

  -- Offline mode
  self.offline = {
    active = false,
    queued_operations = {},
    last_connection_attempt = 0,
    connection_retry_delay = 1000, -- Start with 1 second
  }

  -- State
  self.setup_completed = false

  return self
end

--- Get PostgreSQL module (require with error handling)
---@return table|nil, string?
local function get_postgresql_module()
  -- Try different PostgreSQL Lua modules
  local modules = {
    "pgmoon", -- Most common
    "luasql.postgres", -- LuaSQL
    "postgres", -- Alternative
  }

  for _, module_name in ipairs(modules) do
    local success, pg_module = pcall(require, module_name)
    if success then
      return pg_module, nil
    end
  end

  return nil, "No PostgreSQL Lua module found. Install pgmoon: luarocks install pgmoon"
end

--- Parse PostgreSQL connection URL
---@param url string Connection URL (postgresql://user:pass@host:port/db)
---@return table|nil, string? Parsed connection info or error
local function parse_connection_url(url)
  if not url then
    return nil, "Database URL is required"
  end

  -- Pattern for postgresql://user:password@host:port/database
  local pattern = "^postgresql://([^:]+):([^@]+)@([^:]+):(%d+)/([^?]+)"
  local user, password, host, port, database = url:match(pattern)

  if not user then
    -- Try pattern without port
    pattern = "^postgresql://([^:]+):([^@]+)@([^/]+)/([^?]+)"
    user, password, host, database = url:match(pattern)
    port = "5432" -- Default PostgreSQL port
  end

  if not user then
    return nil, "Invalid PostgreSQL URL format. Expected: postgresql://user:pass@host:port/database"
  end

  return {
    user = user,
    password = password,
    host = host,
    port = tonumber(port),
    database = database,
  },
    nil
end

--- Get environment-based configuration
---@return table Configuration from environment
function PostgreSQLBackend:get_env_config()
  local env_config = {
    database_url = os.getenv("SCREW_DB_URL"),
    user_id = os.getenv("SCREW_USER_EMAIL") or os.getenv("SCREW_USER_ID"),
    project_name = nil, -- Will be auto-detected
  }

  -- Auto-detect project name from git or directory
  local project_root = utils.get_project_root()
  if project_root then
    -- Try git repository name first
    local git_name =
      vim.fn.system("cd " .. vim.fn.shellescape(project_root) .. " && git config --get remote.origin.url 2>/dev/null")
    if vim.v.shell_error == 0 and git_name then
      git_name = git_name:gsub("%.git.*", ""):gsub(".*/", ""):gsub("%s+", "")
      if git_name ~= "" then
        env_config.project_name = git_name
      end
    end

    -- Fallback to directory name
    if not env_config.project_name then
      env_config.project_name = vim.fn.fnamemodify(project_root, ":t")
    end
  end

  return env_config
end

--- Validate collaboration requirements
---@return boolean, string? Valid or error message
function PostgreSQLBackend:validate_collaboration_setup()
  local env_config = self:get_env_config()

  if not env_config.database_url then
    return false, "SCREW_DB_URL environment variable is required for collaboration mode"
  end

  if not env_config.user_id then
    return false, "SCREW_USER_EMAIL or SCREW_USER_ID environment variable is required for collaboration mode"
  end

  if not env_config.project_name then
    return false, "Could not detect project name. Ensure you're in a git repository or valid project directory"
  end

  return true, nil
end

--- Check if we should attempt reconnection (with exponential backoff)
---@return boolean Should attempt reconnection
function PostgreSQLBackend:should_attempt_reconnection()
  local now = vim.loop.now()
  local time_since_last_attempt = now - self.offline.last_connection_attempt

  -- Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
  local max_delay = 30000
  if time_since_last_attempt < math.min(self.offline.connection_retry_delay, max_delay) then
    return false
  end

  return true
end

--- Connect to PostgreSQL database
---@return boolean, string? Success or error message
function PostgreSQLBackend:connect()
  if self.connection.is_connected then
    return true
  end

  -- Check retry backoff
  if not self:should_attempt_reconnection() then
    return false, "Connection retry backoff active"
  end

  self.offline.last_connection_attempt = vim.loop.now()

  -- Get PostgreSQL module
  local pg_module, pg_error = get_postgresql_module()
  if not pg_module then
    return false, pg_error
  end

  -- Get environment configuration
  local env_config = self:get_env_config()

  -- Parse connection URL
  local conn_info, parse_error = parse_connection_url(env_config.database_url)
  if not conn_info then
    return false, parse_error
  end

  -- Store configuration
  self.connection.url = env_config.database_url
  self.connection.user_id = env_config.user_id
  self.connection.project_name = env_config.project_name

  -- Connect to database
  local success, result = pcall(function()
    if pg_module.new then
      -- pgmoon style
      local pg = pg_module.new(conn_info)
      local connect_success, connect_error = pg:connect()
      if not connect_success then
        error(connect_error or "Failed to connect to PostgreSQL")
      end
      return pg
    else
      -- LuaSQL style
      local env = pg_module.postgres()
      return env:connect(conn_info.database, conn_info.user, conn_info.password, conn_info.host, conn_info.port)
    end
  end)

  if not success then
    self.connection.last_error = result
    self.connection.retry_count = self.connection.retry_count + 1

    -- Increase retry delay (exponential backoff)
    self.offline.connection_retry_delay = self.offline.connection_retry_delay * 2
    self.offline.active = true

    return false, "PostgreSQL connection failed: " .. tostring(result)
  end

  self.connection.handle = result
  self.connection.is_connected = true
  self.connection.retry_count = 0

  -- Reset offline mode on successful connection
  if self.offline.active then
    self:recover_from_offline_mode()
  end

  -- Get or create project
  local project_success, project_error = self:ensure_project()
  if not project_success then
    self:disconnect()
    return false, project_error
  end

  return true, nil
end

--- Disconnect from PostgreSQL
function PostgreSQLBackend:disconnect()
  if self.connection.handle then
    pcall(function()
      if self.connection.handle.disconnect then
        self.connection.handle:disconnect()
      elseif self.connection.handle.close then
        self.connection.handle:close()
      end
    end)
  end

  self.connection.handle = nil
  self.connection.is_connected = false

  -- Stop real-time sync
  self:stop_sync()
end

--- Recover from offline mode by processing queued operations
function PostgreSQLBackend:recover_from_offline_mode()
  if not self.offline.active then
    return
  end

  utils.info_popup(
    "Recovering from offline mode - processing " .. #self.offline.queued_operations .. " queued operations"
  )

  -- Reset offline state
  self.offline.active = false
  self.offline.connection_retry_delay = 1000 -- Reset to 1 second

  -- Process queued operations
  local successful_operations = 0
  local failed_operations = 0

  for _, operation in ipairs(self.offline.queued_operations) do
    local success = self:execute_queued_operation(operation)
    if success then
      successful_operations = successful_operations + 1
    else
      failed_operations = failed_operations + 1
    end
  end

  -- Clear the queue
  self.offline.queued_operations = {}

  -- Report results
  if successful_operations > 0 or failed_operations > 0 then
    local msg = string.format(
      "Offline recovery complete: %d successful, %d failed operations",
      successful_operations,
      failed_operations
    )
    if failed_operations > 0 then
      utils.warn(msg)
    else
      utils.info(msg)
    end
  end
end

--- Execute a queued operation
---@param operation table Queued operation
---@return boolean Success
function PostgreSQLBackend:execute_queued_operation(operation)
  local op_type = operation.type

  if op_type == "save_note" then
    return self:save_note(operation.note)
  elseif op_type == "delete_note" then
    return self:delete_note(operation.note_id)
  elseif op_type == "save_reply" then
    -- This would need to be implemented if we add reply saving
    return true
  else
    utils.warn("Unknown queued operation type: " .. tostring(op_type))
    return false
  end
end

--- Queue an operation for offline mode
---@param operation_type string Type of operation
---@param data table Operation data
function PostgreSQLBackend:queue_operation(operation_type, data)
  if not self.offline.active then
    return
  end

  local operation = {
    type = operation_type,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    data = data,
  }

  -- Add specific fields based on operation type
  if operation_type == "save_note" then
    operation.note = data.note
  elseif operation_type == "delete_note" then
    operation.note_id = data.note_id
  end

  table.insert(self.offline.queued_operations, operation)

  utils.info(
    string.format("Queued %s operation for offline mode (%d total)", operation_type, #self.offline.queued_operations)
  )
end

--- Enter offline mode with user notification
---@param reason string Reason for entering offline mode
function PostgreSQLBackend:enter_offline_mode(reason)
  if self.offline.active then
    return -- Already offline
  end

  self.offline.active = true
  utils.warn_popup("Entering offline mode: " .. reason)
  utils.info_popup("Note operations will be queued and synchronized when connection is restored")

  -- Show user notification
  vim.schedule(function()
    vim.notify("📡 screw.nvim: Offline mode - changes will be synced when database reconnects", vim.log.levels.WARN, {
      title = "Database Connection Lost",
      timeout = 5000,
    })
  end)
end

--- Execute SQL query with error handling
---@param query string SQL query
---@param params table? Query parameters
---@return table|nil, string? Results or error
function PostgreSQLBackend:execute_query(query, params)
  -- Check if we're in offline mode and this is not a connection attempt
  if self.offline.active and not query:lower():find("select get_or_create_project") then
    -- For read-only queries, try to serve from cache
    if query:lower():find("^%s*select") then
      -- This would require more sophisticated caching logic
      -- For now, we'll return empty results for SELECT queries in offline mode
      return {}, nil
    else
      -- For write operations, return error indicating offline mode
      return nil, "Database unavailable - operation will be queued"
    end
  end

  if not self.connection.is_connected then
    local success, error_msg = self:connect()
    if not success then
      -- Enter offline mode if connection fails
      if not self.offline.active then
        self:enter_offline_mode(error_msg or "Connection failed")
      end
      return nil, error_msg
    end
  end

  local success, result = pcall(function()
    local handle = self.connection.handle

    -- Handle different PostgreSQL module APIs
    if handle.query then
      -- pgmoon style
      if params then
        return handle:query(query, unpack(params))
      else
        return handle:query(query)
      end
    else
      -- LuaSQL style
      local cursor = handle:execute(query)
      if not cursor then
        error("Query execution failed")
      end

      local rows = {}
      local row = cursor:fetch({}, "a")
      while row do
        table.insert(rows, row)
        row = cursor:fetch({}, "a")
      end
      cursor:close()

      return rows
    end
  end)

  if not success then
    self.connection.last_error = result
    -- Try to reconnect on connection error
    if tostring(result):match("connection") or tostring(result):match("timeout") then
      self:disconnect()
      -- Enter offline mode if we're not already offline
      if not self.offline.active then
        self:enter_offline_mode("Database connection lost during query")
      end
    end
    return nil, "SQL query failed: " .. tostring(result)
  end

  return result, nil
end

--- Ensure project exists in database
---@return boolean, string? Success or error message
function PostgreSQLBackend:ensure_project()
  local project_name = self.connection.project_name
  local project_path = utils.get_project_root()

  if not project_name or not project_path then
    return false, "Project name and path are required"
  end

  -- Use the get_or_create_project function
  local query = "SELECT get_or_create_project($1, $2) as project_id"
  local result, error_msg = self:execute_query(query, { project_name, project_path })

  if not result then
    return false, error_msg
  end

  if result[1] and result[1].project_id then
    self.connection.project_id = result[1].project_id
    return true, nil
  else
    return false, "Failed to get or create project"
  end
end

--- Convert database row to ScrewNote
---@param row table Database row
---@return ScrewNote
function PostgreSQLBackend:row_to_note(row)
  ---@type ScrewNote
  local note = {
    id = row.id,
    file_path = row.file_path,
    line_number = tonumber(row.line_number),
    author = row.author,
    timestamp = row.timestamp,
    updated_at = row.updated_at,
    comment = row.comment,
    description = row.description,
    cwe = row.cwe,
    state = row.state,
    severity = row.severity,
    source = row.source or "native",
    import_metadata = row.import_metadata and vim.json.decode(row.import_metadata) or nil,
    replies = {},
  }

  -- Parse replies if present (from view)
  if row.replies then
    local replies_json = row.replies
    if type(replies_json) == "string" then
      replies_json = vim.json.decode(replies_json)
    end
    note.replies = replies_json or {}
  end

  return note
end

--- Convert ScrewNote to database parameters
---@param note ScrewNote
---@return table Parameters for SQL query
function PostgreSQLBackend:note_to_params(note)
  return {
    note.id,
    self.connection.project_id,
    note.file_path,
    note.line_number,
    note.author,
    note.timestamp,
    note.updated_at,
    note.comment,
    note.description,
    note.cwe,
    note.state,
    note.severity,
    note.source or "native",
    note.import_metadata and vim.json.encode(note.import_metadata) or nil,
    note.version or 1,
  }
end

--- Initialize PostgreSQL storage backend
function PostgreSQLBackend:setup()
  if self.setup_completed then
    return
  end

  -- Validate collaboration setup
  local valid, error_msg = self:validate_collaboration_setup()
  if not valid then
    utils.error("PostgreSQL backend setup failed: " .. error_msg)
    return
  end

  -- Connect to database
  local success, connect_error = self:connect()
  if not success then
    utils.error("PostgreSQL backend setup failed: " .. connect_error)
    return
  end

  -- Load existing notes
  self:load_notes()

  -- Start real-time sync if enabled
  if self.collaboration_config.enabled ~= false then
    self:start_sync()
  end

  self.setup_completed = true
  utils.info("PostgreSQL backend initialized for project: " .. (self.connection.project_name or "unknown"))
end

--- Load notes from PostgreSQL database
function PostgreSQLBackend:load_notes()
  if not self.connection.project_id then
    return
  end

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
    WHERE n.project_id = $1
    ORDER BY n.created_at DESC
  ]]

  local result, error_msg = self:execute_query(query, { self.connection.project_id })
  if not result then
    utils.error("Failed to load notes: " .. (error_msg or "unknown error"))
    return
  end

  -- Clear and rebuild cache
  self.cache.notes = {}

  for _, row in ipairs(result) do
    local note = self:row_to_note(row)
    self.cache.notes[note.id] = note
  end

  self.cache.dirty = false
  self.cache.last_sync = vim.loop.now()
end

--- Save notes to PostgreSQL database
---@return boolean Success
function PostgreSQLBackend:save_notes()
  -- PostgreSQL backend saves notes individually, not in batch
  -- This method is kept for interface compatibility
  return true
end

--- Get all notes
---@return ScrewNote[]
function PostgreSQLBackend:get_all_notes()
  local notes = {}
  for _, note in pairs(self.cache.notes) do
    table.insert(notes, note)
  end
  return notes
end

--- Get note by ID
---@param id string Note ID
---@return ScrewNote?
function PostgreSQLBackend:get_note(id)
  return self.cache.notes[id]
end

--- Save or update a single note
---@param note ScrewNote
---@return boolean Success
function PostgreSQLBackend:save_note(note)
  -- If we're offline, queue the operation and update local cache
  if self.offline.active then
    -- Ensure we have required fields
    note.id = note.id or utils.generate_id()
    note.author = note.author or self.connection.user_id
    note.timestamp = note.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")

    -- Update local cache
    self.cache.notes[note.id] = note
    self.cache.dirty = true

    -- Queue for later sync
    self:queue_operation("save_note", { note = vim.deepcopy(note) })

    utils.info("Note saved locally (offline mode) - will sync when connection restored")
    return true
  end

  if not self.connection.project_id then
    return false
  end

  -- Check if this is an update and verify ownership
  local existing_note = self.cache.notes[note.id]
  if existing_note then
    if existing_note.author ~= self.connection.user_id then
      utils.error("Cannot edit note: only the author (" .. existing_note.author .. ") can modify this note")
      return false
    end

    -- Update existing note
    note.updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
    note.version = (existing_note.version or 1) + 1

    local query = [[
      UPDATE notes SET
        file_path = $3, line_number = $4, author = $5, timestamp = $6,
        updated_at = $7, comment = $8, description = $9, cwe = $10,
        state = $11, severity = $12, source = $13, import_metadata = $14,
        version = $15
      WHERE id = $1 AND project_id = $2
    ]]

    local params = self:note_to_params(note)
    local result, error_msg = self:execute_query(query, params)

    if not result then
      utils.error("Failed to update note: " .. (error_msg or "unknown error"))
      return false
    end
  else
    -- Insert new note
    note.author = note.author or self.connection.user_id
    note.timestamp = note.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")
    note.version = 1

    -- Generate ID if not present
    if not note.id then
      note.id = utils.generate_id()
    end

    local query = [[
      INSERT INTO notes (
        id, project_id, file_path, line_number, author, timestamp,
        updated_at, comment, description, cwe, state, severity,
        source, import_metadata, version
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
    ]]

    local params = self:note_to_params(note)
    local result, error_msg = self:execute_query(query, params)

    if not result then
      utils.error("Failed to insert note: " .. (error_msg or "unknown error"))
      return false
    end
  end

  -- Update cache
  self.cache.notes[note.id] = note
  self.cache.dirty = true

  return true
end

--- Delete a note
---@param id string Note ID
---@return boolean Success
function PostgreSQLBackend:delete_note(id)
  local existing_note = self.cache.notes[id]
  if not existing_note then
    return false
  end

  -- Check ownership
  if existing_note.author ~= self.connection.user_id then
    utils.error("Cannot delete note: only the author (" .. existing_note.author .. ") can delete this note")
    return false
  end

  -- If we're offline, queue the operation and remove from local cache
  if self.offline.active then
    -- Remove from local cache
    self.cache.notes[id] = nil
    self.cache.dirty = true

    -- Queue for later sync
    self:queue_operation("delete_note", { note_id = id })

    utils.info("Note deleted locally (offline mode) - will sync when connection restored")
    return true
  end

  local query = "DELETE FROM notes WHERE id = $1 AND project_id = $2"
  local result, error_msg = self:execute_query(query, { id, self.connection.project_id })

  if not result then
    utils.error("Failed to delete note: " .. (error_msg or "unknown error"))
    return false
  end

  -- Remove from cache
  self.cache.notes[id] = nil
  self.cache.dirty = true

  return true
end

--- Get notes for a specific file
---@param file_path string Relative file path
---@return ScrewNote[]
function PostgreSQLBackend:get_notes_for_file(file_path)
  local file_notes = {}
  for _, note in pairs(self.cache.notes) do
    if note.file_path == file_path then
      table.insert(file_notes, note)
    end
  end
  return file_notes
end

--- Get notes for a specific line
---@param file_path string Relative file path
---@param line_number integer Line number
---@return ScrewNote[]
function PostgreSQLBackend:get_notes_for_line(file_path, line_number)
  local line_notes = {}
  for _, note in pairs(self.cache.notes) do
    if note.file_path == file_path and note.line_number == line_number then
      table.insert(line_notes, note)
    end
  end
  return line_notes
end

--- Clear all notes (for testing)
function PostgreSQLBackend:clear_notes()
  if not self.connection.project_id then
    return
  end

  local query = "DELETE FROM notes WHERE project_id = $1"
  local result, _ = self:execute_query(query, { self.connection.project_id })

  if result then
    self.cache.notes = {}
    self.cache.dirty = true
  end
end

--- Force save notes (PostgreSQL is always synchronized)
---@return boolean Success
function PostgreSQLBackend:force_save()
  return true
end

--- Get storage statistics
---@return table Statistics
function PostgreSQLBackend:get_storage_stats()
  if not self.connection.project_id then
    return {
      backend = "postgresql",
      connected = false,
      notes_count = 0,
    }
  end

  local query = [[
    SELECT
      COUNT(*) as total_notes,
      COUNT(CASE WHEN state = 'vulnerable' THEN 1 END) as vulnerable_notes,
      COUNT(CASE WHEN state = 'not_vulnerable' THEN 1 END) as safe_notes,
      COUNT(CASE WHEN state = 'todo' THEN 1 END) as todo_notes,
      COUNT(DISTINCT author) as contributors
    FROM notes WHERE project_id = $1
  ]]

  local result, _ = self:execute_query(query, { self.connection.project_id })

  local stats = {
    backend = "postgresql",
    connected = self.connection.is_connected,
    project_name = self.connection.project_name,
    project_id = self.connection.project_id,
    user_id = self.connection.user_id,
    notes_count = vim.tbl_count(self.cache.notes),
    cache_dirty = self.cache.dirty,
    sync_enabled = self.sync.enabled,
    offline_mode = self.offline.active,
    queued_operations = #self.offline.queued_operations,
    connection_retry_delay = self.offline.connection_retry_delay,
    last_connection_attempt = self.offline.last_connection_attempt,
  }

  if result and result[1] then
    local db_stats = result[1]
    stats.total_notes = tonumber(db_stats.total_notes) or 0
    stats.vulnerable_notes = tonumber(db_stats.vulnerable_notes) or 0
    stats.safe_notes = tonumber(db_stats.safe_notes) or 0
    stats.todo_notes = tonumber(db_stats.todo_notes) or 0
    stats.contributors = tonumber(db_stats.contributors) or 0
  end

  return stats
end

--- Replace all notes (for migration)
---@param notes ScrewNote[] New notes
---@return boolean Success
function PostgreSQLBackend:replace_all_notes(notes)
  if not self.connection.project_id then
    return false
  end

  -- Begin transaction
  local transaction_query = "BEGIN"
  local result, _ = self:execute_query(transaction_query)
  if not result then
    return false
  end

  -- Clear existing notes
  local clear_query = "DELETE FROM notes WHERE project_id = $1"
  local clear_result, _ = self:execute_query(clear_query, { self.connection.project_id })
  if not clear_result then
    self:execute_query("ROLLBACK")
    return false
  end

  -- Insert all notes
  for _, note in ipairs(notes) do
    note.author = note.author or self.connection.user_id
    note.timestamp = note.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")
    note.version = 1

    if not note.id then
      note.id = utils.generate_id()
    end

    local insert_query = [[
      INSERT INTO notes (
        id, project_id, file_path, line_number, author, timestamp,
        updated_at, comment, description, cwe, state, severity,
        source, import_metadata, version
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
    ]]

    local params = self:note_to_params(note)
    local insert_result, _ = self:execute_query(insert_query, params)
    if not insert_result then
      self:execute_query("ROLLBACK")
      return false
    end
  end

  -- Commit transaction
  local commit_result, _ = self:execute_query("COMMIT")
  if not commit_result then
    return false
  end

  -- Reload cache
  self:load_notes()

  return true
end

--- Start real-time synchronization
function PostgreSQLBackend:start_sync()
  if not self.connection.is_connected or self.sync.enabled then
    return
  end

  -- TODO: Implement LISTEN/NOTIFY for real-time sync
  -- This is a complex feature that requires careful handling
  -- For now, we'll use periodic polling as a fallback

  self.sync.enabled = true
  self.sync.timer = vim.loop.new_timer()

  if self.sync.timer then
    self.sync.timer:start(
      self.collaboration_config.sync_interval or 5000,
      self.collaboration_config.sync_interval or 5000,
      vim.schedule_wrap(function()
        self:periodic_sync()
      end)
    )
  end
end

--- Stop real-time synchronization
function PostgreSQLBackend:stop_sync()
  if self.sync.timer then
    self.sync.timer:stop()
    self.sync.timer:close()
    self.sync.timer = nil
  end

  self.sync.enabled = false
  self.sync.listening = false
end

--- Periodic sync fallback (when LISTEN/NOTIFY is not available)
function PostgreSQLBackend:periodic_sync()
  -- If offline, try to reconnect periodically
  if self.offline.active then
    self:attempt_reconnection()
    return
  end

  if not self.connection.is_connected then
    return
  end

  -- Simple approach: reload notes if they might have changed
  -- In a full implementation, this would be more sophisticated
  local current_time = vim.loop.now()
  if current_time - self.cache.last_sync > (self.collaboration_config.sync_interval or 5000) then
    self:load_notes()
  end
end

--- Attempt to reconnect when in offline mode
function PostgreSQLBackend:attempt_reconnection()
  if not self.offline.active then
    return true
  end

  if not self:should_attempt_reconnection() then
    return false
  end

  utils.info("Attempting to reconnect to database...")

  local success, error_msg = self:connect()
  if success then
    utils.success("Database connection restored")
    return true
  else
    utils.warn("Reconnection failed: " .. (error_msg or "unknown error"))
    return false
  end
end

--- Force a reconnection attempt (ignoring backoff)
---@return boolean Success
function PostgreSQLBackend:force_reconnect()
  -- Reset retry delay and last attempt time
  self.offline.connection_retry_delay = 1000
  self.offline.last_connection_attempt = 0

  return self:attempt_reconnection()
end

--- Get offline mode status
---@return table Offline status information
function PostgreSQLBackend:get_offline_status()
  return {
    active = self.offline.active,
    queued_operations_count = #self.offline.queued_operations,
    last_connection_attempt = self.offline.last_connection_attempt,
    connection_retry_delay = self.offline.connection_retry_delay,
    can_retry_now = self:should_attempt_reconnection(),
  }
end

return PostgreSQLBackend
