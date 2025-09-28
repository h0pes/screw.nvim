--- Mode detection logic for screw.nvim collaboration
---
--- This module determines whether to use local or collaborative storage
--- based on existing data and user preferences.
---

local utils = require("screw.utils")
local config = require("screw.config")

---@class ModeDetector
local ModeDetector = {}

---@class DetectionResult
---@field mode "local"|"collaborative" Detected mode
---@field reason string Reason for the detection
---@field requires_migration boolean Whether migration is needed
---@field local_notes_found boolean Local notes exist
---@field db_available boolean Database is available
---@field db_notes_found boolean Database notes exist
---@field user_choice string? User's explicit choice

--- Check for existing local notes
---@return boolean, integer Local notes found and count
local function check_local_notes()
  local project_root = utils.get_project_root()
  if not project_root then
    return false, 0
  end

  -- Look for JSON note files
  local json_pattern = project_root .. "/screw_notes_*.json"
  local json_files = vim.fn.glob(json_pattern, false, true)

  -- Look for SQLite files
  local sqlite_pattern = project_root .. "/*.db"
  local sqlite_files = vim.fn.glob(sqlite_pattern, false, true)

  local total_notes = 0
  local has_notes = false

  -- Count notes in JSON files
  for _, json_file in ipairs(json_files) do
    local success, content = pcall(vim.fn.readfile, json_file)
    if success then
      local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and type(data) == "table" and data.notes then
        total_notes = total_notes + #data.notes
        has_notes = true
      end
    end
  end

  -- Basic SQLite check (would need actual SQLite connection to count)
  if #sqlite_files > 0 then
    has_notes = true
    -- Approximate count - in reality would need to query SQLite
    total_notes = total_notes + 10 -- Placeholder
  end

  return has_notes, total_notes
end

--- Check collaboration API availability and existing notes
---@return boolean, boolean, integer API available, has notes, count
local function check_database_notes()
  local api_url = os.getenv("SCREW_API_URL")
  if not api_url then
    return false, false, 0
  end

  -- Try to connect to HTTP API and check for notes
  local HttpBackend = require("screw.notes.storage.http")
  local temp_backend = HttpBackend.new({ backend = "http" })

  local success, _ = temp_backend:connect()
  if not success then
    return false, false, 0
  end

  -- Load notes for this project
  local notes = temp_backend:load_notes()
  temp_backend:disconnect()

  local note_count = #notes
  return true, note_count > 0, note_count
end

--- Get user's mode preference through UI prompt
---@param context table Context information for the prompt
---@return string? User choice: "local", "collaborative", or nil for cancel
local function get_user_mode_choice(context)
  local choices = {}
  local messages = {}

  -- Build context message
  local context_msg = "screw.nvim: Choose storage mode for this project\n\n"

  if context.local_notes_found then
    context_msg = context_msg .. string.format("• Found %d local notes\n", context.local_count or 0)
  end

  if context.db_notes_found then
    context_msg = context_msg .. string.format("• Found %d notes in database\n", context.db_count or 0)
  end

  if not context.local_notes_found and not context.db_notes_found then
    context_msg = context_msg .. "• No existing notes found\n"
  end

  context_msg = context_msg .. "\nChoose how to store security notes:\n\n"

  -- Local mode option
  table.insert(choices, "&Local")
  table.insert(messages, "Local: Store notes in JSON files (single user)")

  -- Collaborative mode option (only if database is available)
  if context.db_available then
    table.insert(choices, "&Collaborative")
    table.insert(messages, "Collaborative: Store notes via API server (multi-user)")
  else
    table.insert(messages, "Collaborative: Unavailable (SCREW_API_URL not set)")
  end

  -- Migration options
  if context.local_notes_found and context.db_available then
    table.insert(choices, "&Migrate to DB")
    table.insert(messages, "Migrate: Move local notes to database")
  end

  if context.db_notes_found then
    table.insert(choices, "&Export from DB")
    table.insert(messages, "Export: Download database notes to local files")
  end

  table.insert(choices, "&Cancel")

  -- Show the prompt
  local full_message = context_msg .. table.concat(messages, "\n")

  local choice = vim.fn.confirm(full_message, table.concat(choices, "\n"), 1)

  if choice == 0 or choice > #choices then
    return nil -- Cancelled
  end

  local selected = choices[choice]:gsub("&", "")

  -- Map choices to modes
  if selected == "Local" then
    return "local"
  elseif selected == "Collaborative" then
    return "collaborative"
  elseif selected == "Migrate to DB" then
    return "migrate_to_db"
  elseif selected == "Export from DB" then
    return "export_from_db"
  else
    return nil
  end
end

--- Detect appropriate storage mode
---@return DetectionResult
function ModeDetector.detect_mode()
  local result = {
    mode = "local", -- Default fallback
    reason = "default",
    requires_migration = false,
    local_notes_found = false,
    db_available = false,
    db_notes_found = false,
    user_choice = nil,
  }

  -- Check local notes
  local has_local, local_count = check_local_notes()
  result.local_notes_found = has_local
  result.local_count = local_count

  -- Check database availability and notes
  local db_available, has_db_notes, db_count = check_database_notes()
  result.db_available = db_available
  result.db_notes_found = has_db_notes
  result.db_count = db_count

  -- Decision logic
  if has_local and has_db_notes then
    -- Both exist - ask user
    result.user_choice = get_user_mode_choice(result)

    if result.user_choice == "collaborative" then
      result.mode = "collaborative"
      result.reason = "user chose collaborative with existing data in both locations"
    elseif result.user_choice == "migrate_to_db" then
      result.mode = "collaborative"
      result.requires_migration = true
      result.reason = "user chose to migrate local notes to database"
    elseif result.user_choice == "export_from_db" then
      result.mode = "local"
      result.requires_migration = true
      result.reason = "user chose to export database notes to local"
    elseif result.user_choice == "local" then
      result.mode = "local"
      result.reason = "user chose local with existing data in both locations"
    else
      -- User cancelled - default to local
      result.mode = "local"
      result.reason = "user cancelled choice, defaulted to local"
    end
  elseif has_local and not has_db_notes then
    -- Only local notes exist
    if db_available then
      -- Database is available but empty - ask user
      result.user_choice = get_user_mode_choice(result)

      if result.user_choice == "collaborative" then
        result.mode = "collaborative"
        result.requires_migration = false
        result.reason = "user chose collaborative, local notes will be migrated"
      elseif result.user_choice == "migrate_to_db" then
        result.mode = "collaborative"
        result.requires_migration = true
        result.reason = "user chose to migrate local notes to database"
      else
        result.mode = "local"
        result.reason = "user chose to continue with local notes"
      end
    else
      -- No database available
      result.mode = "local"
      result.reason = "local notes found, no database available"
    end
  elseif not has_local and has_db_notes then
    -- Only database notes exist
    result.mode = "collaborative"
    result.reason = "database notes found, continuing in collaborative mode"
  elseif not has_local and not has_db_notes then
    -- No notes anywhere - check if database is available
    if db_available then
      -- Ask user for preference
      result.user_choice = get_user_mode_choice(result)

      if result.user_choice == "collaborative" then
        result.mode = "collaborative"
        result.reason = "user chose collaborative for new project"
      else
        result.mode = "local"
        result.reason = "user chose local for new project"
      end
    else
      -- No database available
      result.mode = "local"
      result.reason = "new project, no database available"
    end
  end

  return result
end

--- Apply the detected mode to the configuration
---@param detection_result DetectionResult
---@return boolean Success
function ModeDetector.apply_mode(detection_result)
  local current_config = config.get()

  if detection_result.mode == "collaborative" then
    -- Configure for collaborative mode
    current_config.storage.backend = "http"
    current_config.collaboration.enabled = true

    -- Validate environment variables
    local env_config = {}
    env_config.api_url = os.getenv("SCREW_API_URL")
    env_config.user_id = os.getenv("SCREW_USER_EMAIL") or os.getenv("SCREW_USER_ID")

    if not env_config.api_url then
      utils.error("SCREW_API_URL environment variable is required for collaborative mode")
      return false
    end

    if not env_config.user_id then
      utils.error("SCREW_USER_EMAIL or SCREW_USER_ID environment variable is required for collaborative mode")
      return false
    end

    current_config.collaboration.api_url = env_config.api_url
    current_config.collaboration.user_id = env_config.user_id

    utils.collaboration_status("Configured for collaborative mode with HTTP API")
  else
    -- Configure for local mode
    current_config.storage.backend = "json"
    current_config.collaboration.enabled = false

    utils.info("Configured for local mode with JSON storage")
  end

  -- Note: Configuration is already updated in the config.options object
  -- No separate update_config method needed

  return true
end

--- Handle migration based on detection result
---@param detection_result DetectionResult
---@return boolean Success
function ModeDetector.handle_migration(detection_result)
  if not detection_result.requires_migration then
    return true
  end

  -- Migration logic would go here
  -- This is a placeholder for the migration utilities
  local MigrationUtil = require("screw.collaboration.migration")

  if detection_result.user_choice == "migrate_to_db" then
    utils.info("Starting migration from local to database...")
    return MigrationUtil.migrate_local_to_db()
  elseif detection_result.user_choice == "export_from_db" then
    utils.info("Starting export from database to local...")
    return MigrationUtil.migrate_db_to_local()
  end

  return true
end

--- Get a summary of the current mode detection
---@return table Summary information
function ModeDetector.get_status()
  local local_notes, local_count = check_local_notes()
  local db_available, db_notes, db_count = check_database_notes()

  return {
    local_notes_found = local_notes,
    local_notes_count = local_count,
    db_available = db_available,
    db_notes_found = db_notes,
    db_notes_count = db_count,
    current_backend = config.get_option("storage.backend"),
    collaboration_enabled = config.get_option("collaboration.enabled"),
  }
end

--- Force a specific mode (for testing or explicit user choice)
---@param mode "local"|"collaborative" Mode to force
---@return boolean Success
function ModeDetector.force_mode(mode)
  local detection_result = {
    mode = mode,
    reason = "forced by user",
    requires_migration = false,
    local_notes_found = false,
    db_available = false,
    db_notes_found = false,
    user_choice = mode,
  }

  return ModeDetector.apply_mode(detection_result)
end

return ModeDetector
