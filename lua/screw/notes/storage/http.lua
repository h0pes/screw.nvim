--- HTTP-based storage backend for screw.nvim collaboration
---
--- This backend uses HTTP requests to communicate with a REST API server
--- instead of direct database connections, eliminating dependency requirements.
---

local utils = require("screw.utils")

---@class HttpBackend
local HttpBackend = {}
HttpBackend.__index = HttpBackend
HttpBackend.__class = "HttpBackend"

--- Create a new HTTP backend instance
---@param config table Storage configuration
---@return HttpBackend
function HttpBackend.new(config)
  local self = setmetatable({
    config = config,
    api_url = os.getenv("SCREW_API_URL") or "http://localhost:3000/api",
    user_id = os.getenv("SCREW_USER_EMAIL") or os.getenv("SCREW_USER_ID"),
    project_name = nil,
    connected = false,
    notes_cache = {}, -- Local cache to match JSON backend behavior
  }, HttpBackend)

  -- Auto-detect project name from project root
  local project_root = utils.get_project_root()
  self.project_name = vim.fn.fnamemodify(project_root, ":t") -- Get directory name

  return self
end

--- Make HTTP request using system curl
---@param method string HTTP method (GET, POST, PUT, DELETE)
---@param endpoint string API endpoint
---@param data table? Request body data
---@return table?, string? Response data or nil, error message
function HttpBackend:http_request(method, endpoint, data)
  local url = self.api_url .. endpoint
  local cmd = { "curl", "-s", "-X", method, "-H", "Content-Type: application/json" }
  local _ = endpoint:match("/replies")

  if data then
    table.insert(cmd, "-d")
    table.insert(cmd, vim.json.encode(data))
  end

  table.insert(cmd, url)

  local result = vim.fn.system(cmd)
  local success = vim.v.shell_error == 0

  if not success then
    return nil, "HTTP request failed: " .. (result or "unknown error")
  end

  if result == "" then
    return {}, nil
  end

  local ok, decoded = pcall(vim.json.decode, result)
  if not ok then
    return nil, "Invalid JSON response: " .. result
  end

  return decoded, nil
end

--- Test connection to HTTP API
---@return boolean, string? Success, error message
function HttpBackend:connect()
  if not self.api_url then
    return false, "SCREW_API_URL environment variable not set"
  end

  if not self.user_id then
    return false, "SCREW_USER_EMAIL or SCREW_USER_ID environment variable not set"
  end

  -- Test API connectivity
  local _, err = self:http_request("GET", "/health")
  if err then
    return false, "Cannot connect to collaboration server: " .. err
  end

  self.connected = true
  return true, nil
end

--- Disconnect from HTTP API
function HttpBackend:disconnect()
  self.connected = false
end

--- Check if connected to HTTP API
---@return boolean
function HttpBackend:is_connected()
  return self.connected
end

--- Load all notes from HTTP API
---@return ScrewNote[]
function HttpBackend:load_notes()
  if not self.connected then
    return self.notes_cache
  end

  local endpoint = "/notes/" .. self.project_name

  local response, err = self:http_request("GET", endpoint)
  if err then
    utils.warn("Failed to load notes from server: " .. err)
    return self.notes_cache
  end

  -- Update local cache (timestamps are now properly formatted by server)
  self.notes_cache = response.notes or {}
  return self.notes_cache
end

--- Refresh signs for all open buffers
function HttpBackend:refresh_all_signs()
  local signs_success, signs = pcall(require, "screw.signs")
  if signs_success then
    pcall(signs.refresh_all_signs)
  end
end

--- Save a note to HTTP API
---@param note ScrewNote
---@return boolean Success
function HttpBackend:save_note(note)
  if not self.connected then
    -- Store in cache for offline mode
    local found = false
    for i, cached_note in ipairs(self.notes_cache) do
      if cached_note.id == note.id then
        self.notes_cache[i] = note
        found = true
        break
      end
    end
    if not found then
      table.insert(self.notes_cache, note)
    end
    return true
  end

  -- Only normalize to relative path if it's actually absolute
  local utils = require("screw.utils")
  local relative_file_path = note.file_path

  -- Only convert if it's an absolute path
  if note.file_path:sub(1, 1) == "/" or note.file_path:match("^%a:") then
    relative_file_path = utils.get_relative_path(note.file_path)
  end

  -- Ensure we never store absolute paths
  if relative_file_path:sub(1, 1) == "/" then
    utils.error("CRITICAL: Attempted to store absolute path in database: " .. relative_file_path)
    return false
  end

  -- Add project context and remove ID for new notes to let server generate it
  local note_data = {
    file_path = relative_file_path, -- Always use relative path
    line_number = note.line_number,
    author = note.author,
    comment = note.comment,
    description = note.description,
    cwe = note.cwe,
    state = note.state,
    severity = note.severity,
    source = note.source or "native",
    import_metadata = note.import_metadata, -- Include import metadata for SARIF imports
    project_name = self.project_name,
    user_id = self.user_id,
  }

  -- For HTTP backend, always use POST for new notes and let server generate UUID
  -- Only use PUT if the note already exists in our cache (was loaded from server)
  local endpoint, method
  local exists_in_cache = false

  -- Check if note exists in our cache (means it came from server)
  if note.id then
    for _, cached_note in ipairs(self.notes_cache) do
      if cached_note.id == note.id then
        exists_in_cache = true
        break
      end
    end
  end

  if exists_in_cache then
    -- Existing note from server - use PUT to update
    endpoint = "/notes/" .. note.id
    method = "PUT"
  else
    -- New note - use POST and let server generate UUID
    endpoint = "/notes"
    method = "POST"
    -- Don't send the client-generated ID to server
    note_data.id = nil
  end

  local response, err = self:http_request(method, endpoint, note_data)
  if err then
    utils.error("Failed to save note: " .. err)
    return false
  end

  -- Update note with server response (e.g., generated ID)
  if response and response.note then
    for key, value in pairs(response.note) do
      note[key] = value
    end
  end

  -- Refresh cache from server to ensure consistency
  self:load_notes()

  return true
end

--- Delete a note from HTTP API
---@param note_id string
---@return boolean Success
function HttpBackend:delete_note(note_id)
  if not self.connected then
    -- Remove from cache in offline mode
    for i, note in ipairs(self.notes_cache) do
      if note.id == note_id then
        table.remove(self.notes_cache, i)
        break
      end
    end
    return true
  end

  local _, err = self:http_request("DELETE", "/notes/" .. note_id)
  if err then
    utils.error("Failed to delete note: " .. err)
    return false
  end

  -- Refresh cache from server to ensure consistency
  self:load_notes()

  return true
end

--- Add a reply to a note via HTTP API
---@param parent_id string
---@param reply ScrewReply
---@return boolean Success
function HttpBackend:add_reply(parent_id, reply)
  if not self.connected then
    return false
  end

  local reply_data = vim.tbl_deep_extend("force", reply, {
    parent_id = parent_id,
    user_id = self.user_id,
  })

  -- Remove client-generated ID - let the database generate a proper UUID
  reply_data.id = nil

  local _, err = self:http_request("POST", "/notes/" .. parent_id .. "/replies", reply_data)
  if err then
    utils.error("Failed to add reply: " .. err)
    return false
  end

  -- Refresh cache from server to ensure replies are loaded
  self:load_notes()

  return true
end

--- Get storage statistics
---@return table Storage stats
function HttpBackend:get_storage_stats()
  local response, err = self:http_request("GET", "/stats/" .. self.project_name)
  if err then
    return {
      backend_type = "http",
      connected = self.connected,
      api_url = self.api_url,
      user_id = self.user_id,
      project_name = self.project_name,
      total_notes = 0,
      error = err,
    }
  end

  return vim.tbl_deep_extend("force", response, {
    backend_type = "http",
    connected = self.connected,
    api_url = self.api_url,
    user_id = self.user_id,
    project_name = self.project_name,
  })
end

--- Setup the HTTP backend (required by StorageBackend interface)
function HttpBackend:setup()
  local success, err = self:connect()
  if not success then
    utils.warn("HTTP backend setup failed: " .. (err or "unknown error"))
    return
  end

  -- Load notes from server to populate cache
  self:load_notes()

  -- Initialize signs for loaded notes
  local signs_success, signs = pcall(require, "screw.signs")
  if signs_success then
    for _, note in ipairs(self.notes_cache) do
      pcall(signs.on_note_added, note)
    end
  end
end

--- Get all notes (required by StorageBackend interface)
---@return ScrewNote[]
function HttpBackend:get_all_notes()
  -- For HTTP backend, always refresh from server to get latest notes
  -- This ensures collaboration works properly
  self:load_notes()
  return self.notes_cache
end

--- Get a specific note by ID
---@param id string
---@return ScrewNote?
function HttpBackend:get_note(id)
  local response, err = self:http_request("GET", "/notes/note/" .. id)
  if err then
    utils.warn("Failed to get note: " .. err)
    return nil
  end
  return response.note
end

--- Get notes for a specific file
---@param file_path string
---@return ScrewNote[]
function HttpBackend:get_notes_for_file(file_path)
  self:get_all_notes() -- Ensure cache is loaded

  -- Convert to relative path only if it's absolute
  local utils = require("screw.utils")
  local search_relative_path = file_path

  if file_path:sub(1, 1) == "/" or file_path:match("^%a:") then
    search_relative_path = utils.get_relative_path(file_path)
  end

  local file_notes = {}
  for _, note in ipairs(self.notes_cache) do
    -- All notes should already be stored with relative paths
    -- But double-check by normalizing if needed
    local note_path = note.file_path
    if note_path:sub(1, 1) == "/" then
      note_path = utils.get_relative_path(note_path)
    end

    if note_path == search_relative_path then
      table.insert(file_notes, note)
    end
  end

  return file_notes
end

--- Get notes for a specific line in a file
---@param file_path string
---@param line_number number
---@return ScrewNote[]
function HttpBackend:get_notes_for_line(file_path, line_number)
  self:get_all_notes() -- Ensure cache is loaded

  -- Convert to relative path only if it's absolute
  local utils = require("screw.utils")
  local search_relative_path = file_path

  if file_path:sub(1, 1) == "/" or file_path:match("^%a:") then
    search_relative_path = utils.get_relative_path(file_path)
  end

  local line_notes = {}
  for _, note in ipairs(self.notes_cache) do
    -- All notes should already be stored with relative paths
    local note_path = note.file_path
    if note_path:sub(1, 1) == "/" then
      note_path = utils.get_relative_path(note_path)
    end

    if note_path == search_relative_path and note.line_number == line_number then
      table.insert(line_notes, note)
    end
  end
  return line_notes
end

--- Save all notes (batch operation)
---@return boolean Success
function HttpBackend:save_notes()
  -- For HTTP backend, notes are saved individually via save_note()
  -- This method is kept for interface compatibility
  return true
end

--- Clear all notes for the project
---@return boolean Success
function HttpBackend:clear_notes()
  if not self.connected then
    return false
  end

  local _, err = self:http_request("DELETE", "/notes/" .. self.project_name)
  if err then
    utils.error("Failed to clear notes: " .. err)
    return false
  end

  return true
end

--- Force save (for HTTP backend this does nothing as saves are immediate)
---@return boolean Success
function HttpBackend:force_save()
  return true
end

--- Replace all notes with a new set
---@param notes ScrewNote[]
---@return boolean Success
function HttpBackend:replace_all_notes(notes)
  if not self.connected then
    return false
  end

  local _, err = self:http_request("PUT", "/notes/" .. self.project_name .. "/replace", {
    notes = notes,
  })
  if err then
    utils.error("Failed to replace notes: " .. err)
    return false
  end

  return true
end

--- Force reconnection
---@return boolean Success
function HttpBackend:force_reconnect()
  self:disconnect()
  return self:connect()
end

return HttpBackend
