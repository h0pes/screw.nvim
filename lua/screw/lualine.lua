--- Lualine integration for screw.nvim
---
--- This module provides lualine components for displaying security note information
--- in the statusline with full customization support.
---

local M = {}

-- Cache system for performance
local cache = {
  summary = { data = nil, timestamp = 0 },
  file_status = { data = nil, timestamp = 0, file_path = nil },
  line_notes = { data = nil, timestamp = 0, line_number = 0, file_path = nil },
  collab_status = { data = nil, timestamp = 0 },
}

-- Cache invalidation time (milliseconds)
local CACHE_TTL = 100

--- Check if lualine is available
---@return boolean
local function has_lualine()
  return pcall(require, "lualine")
end

--- Get current timestamp
---@return number
local function get_timestamp()
  return vim.loop.hrtime() / 1e6 -- Convert to milliseconds
end

--- Invalidate all caches (called when notes change)
local function invalidate_caches()
  cache.summary.timestamp = 0
  cache.file_status.timestamp = 0
  cache.line_notes.timestamp = 0
end

--- Get cached value or compute new one
---@param cache_key string
---@param compute_fn function
---@param extra_key? any
---@return any
local function get_cached(cache_key, compute_fn, extra_key)
  local entry = cache[cache_key]
  local now = get_timestamp()
  local is_expired = (now - entry.timestamp) > CACHE_TTL

  -- Check if extra key has changed (for file/line specific caches)
  local key_changed = false
  if cache_key == "file_status" then
    local current_file = vim.fn.expand("%:.")
    key_changed = entry.file_path ~= current_file
    if key_changed then
      entry.file_path = current_file
    end
  elseif cache_key == "line_notes" then
    local current_file = vim.fn.expand("%:.")
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    key_changed = entry.file_path ~= current_file or entry.line_number ~= current_line
    if key_changed then
      entry.file_path = current_file
      entry.line_number = current_line
    end
  end

  if is_expired or key_changed or entry.data == nil then
    entry.data = compute_fn()
    entry.timestamp = now
  end

  return entry.data
end

--- Get screw configuration
---@return table
local function get_config()
  local success, config = pcall(require, "screw.config")
  if success then
    return config.get()
  end
  return {}
end

--- Get lualine configuration for screw
---@return table
local function get_lualine_config()
  local config = get_config()
  return config.lualine or {}
end

--- Check if lualine integration is enabled
---@return boolean
local function is_enabled()
  local config = get_lualine_config()
  return config.enabled == true
end

--- Get notes manager
---@return table?
local function get_notes_manager()
  local success, manager = pcall(require, "screw.notes.manager")
  if success then
    return manager
  end
  return nil
end

--- Get collaboration module
---@return table?
local function get_collaboration()
  local success, collaboration = pcall(require, "screw.collaboration")
  if success then
    return collaboration
  end
  return nil
end

--- Build dynamic format string for summary/file_status components (only show non-zero values)
---@param component_name string
---@param data table
---@param icons table
---@return string
local function build_dynamic_format(component_name, data, icons)
  if component_name ~= "summary" and component_name ~= "file_status" then
    return nil -- Not applicable to other components
  end

  local parts = {}

  -- Always show total (including 0)
  if data.total and tonumber(data.total) >= 0 then
    local total_icon = icons.total or ""
    table.insert(parts, total_icon .. (total_icon ~= "" and " " or "") .. data.total)
  end

  -- Only show vulnerable if > 0
  if data.vulnerable and tonumber(data.vulnerable) > 0 then
    local vulnerable_icon = icons.vulnerable or ""
    table.insert(parts, vulnerable_icon .. (vulnerable_icon ~= "" and " " or "") .. data.vulnerable)
  end

  -- Only show todo if > 0
  if data.todo and tonumber(data.todo) > 0 then
    local todo_icon = icons.todo or ""
    table.insert(parts, todo_icon .. (todo_icon ~= "" and " " or "") .. data.todo)
  end

  -- Only show not_vulnerable if > 0
  if data.not_vulnerable and tonumber(data.not_vulnerable) > 0 then
    local safe_icon = icons.not_vulnerable or ""
    table.insert(parts, safe_icon .. (safe_icon ~= "" and " " or "") .. data.not_vulnerable)
  end

  -- Special case for file_status: show clean icon when total is 0
  if component_name == "file_status" and data.is_clean and data.is_clean == true then
    local clean_icon = icons.clean or ""
    return clean_icon
  end

  return table.concat(parts, " ")
end

--- Format component display according to user configuration
---@param component_name string
---@param data table
---@return string
local function format_component(component_name, data)
  local config = get_lualine_config()
  local component_config = config.components and config.components[component_name] or {}

  if not component_config.enabled then
    return ""
  end

  local format = component_config.format or ""
  local icons = component_config.icons or {}

  -- Check if we should use dynamic formatting for summary/file_status components
  local dynamic_result = build_dynamic_format(component_name, data, icons)
  if dynamic_result then
    return dynamic_result
  end

  -- Fallback to original format string processing for other components
  -- Create a complete data table with both values and icons
  local format_data = {}

  -- Add all data values
  for key, value in pairs(data) do
    format_data[key] = tostring(value)
  end

  -- Add icon values - map icon names to actual icons
  for icon_name, icon_value in pairs(icons) do
    format_data[icon_name .. "_icon"] = icon_value
  end

  -- Special handling for dynamic icon mappings
  if data.status and icons[data.status] then
    format_data["status_icon"] = icons[data.status]
  end

  if data.state and icons[data.state] then
    format_data["state_icon"] = icons[data.state]
  end

  -- Replace all placeholders in format string
  local result = format
  for placeholder, replacement in pairs(format_data) do
    result = result:gsub("%%{" .. placeholder .. "}", replacement)
  end

  -- Remove any remaining unreplaced placeholders
  result = result:gsub("%%{[^}]*}", "")

  return result
end

--- Notes Summary Component
--- Shows total notes with breakdown by state
---@return string
function M.screw_summary()
  -- Return empty unless explicitly enabled via external initialization
  -- This prevents any automatic loading when lualine calls this function
  if not package.loaded["screw"] then
    return ""
  end

  -- Only proceed if screw is already loaded and lualine is enabled
  local config = get_config()
  local lualine_config = config.lualine or {}
  if not lualine_config.enabled then
    return ""
  end

  -- Check if storage is initialized to avoid triggering file creation
  local storage = require("screw.notes.storage")
  if not storage.is_initialized() then
    -- Show default empty state without accessing storage
    local lualine_config_obj = get_lualine_config()
    local component_config = lualine_config_obj.components and lualine_config_obj.components.summary or {}

    if not component_config.enabled then
      return ""
    end

    -- Return zero stats when no storage yet
    local data = {
      total = 0,
      vulnerable = 0,
      not_vulnerable = 0,
      todo = 0,
    }
    return format_component("summary", data)
  end

  return get_cached("summary", function()
    local manager = get_notes_manager()
    if not manager then
      return ""
    end

    local stats = manager.get_statistics()
    local component_config = lualine_config.components and lualine_config.components.summary or {}

    if not component_config.enabled then
      return ""
    end

    local data = {
      total = stats.total,
      vulnerable = stats.vulnerable,
      not_vulnerable = stats.not_vulnerable,
      todo = stats.todo,
    }

    return format_component("summary", data)
  end)
end

--- Current File Status Component
--- Shows note count for current file or clean status
---@return string
function M.screw_file_status()
  -- Return empty unless explicitly enabled via external initialization
  -- This prevents any automatic loading when lualine calls this function
  if not package.loaded["screw"] then
    return ""
  end

  -- Only proceed if screw is already loaded and lualine is enabled
  local config = get_config()
  local lualine_config = config.lualine or {}
  if not lualine_config.enabled then
    return ""
  end

  -- Check if storage is initialized to avoid triggering file creation
  local storage = require("screw.notes.storage")
  if not storage.is_initialized() then
    -- Show clean state without accessing storage
    local lualine_config_obj = get_lualine_config()
    local component_config = lualine_config_obj.components and lualine_config_obj.components.file_status or {}

    if not component_config.enabled then
      return ""
    end

    -- Return clean state when no storage yet
    local icons = component_config.icons or {}
    local clean_icon = icons.clean or "✓"

    return string.format("%%#lualine_c_normal# %s clean", clean_icon)
  end

  return get_cached("file_status", function()
    local manager = get_notes_manager()
    if not manager then
      return ""
    end

    local notes = manager.get_current_file_notes()
    local count = #notes
    local config = get_lualine_config()
    local component_config = config.components and config.components.file_status or {}

    if not component_config.enabled then
      return ""
    end

    local has_vulnerable = false
    local has_todo = false

    for _, note in ipairs(notes) do
      if note.state == "vulnerable" then
        has_vulnerable = true
      elseif note.state == "todo" then
        has_todo = true
      end
    end

    local state = "clean"
    if has_vulnerable then
      state = "vulnerable"
    elseif has_todo then
      state = "todo"
    elseif count > 0 then
      state = "safe"
    end

    -- Count notes by state for current file
    local vulnerable_count = 0
    local todo_count = 0
    local safe_count = 0

    for _, note in ipairs(notes) do
      if note.state == "vulnerable" then
        vulnerable_count = vulnerable_count + 1
      elseif note.state == "todo" then
        todo_count = todo_count + 1
      elseif note.state == "not_vulnerable" then
        safe_count = safe_count + 1
      end
    end

    local data = {
      total = count,
      vulnerable = vulnerable_count,
      todo = todo_count,
      not_vulnerable = safe_count,
      state = state,
      is_clean = count == 0,
    }

    return format_component("file_status", data)
  end)
end

--- Current Line Indicator Component
--- Shows note info when cursor is on line with notes
---@return string
function M.screw_line_notes()
  -- Return empty unless explicitly enabled via external initialization
  -- This prevents any automatic loading when lualine calls this function
  if not package.loaded["screw"] then
    return ""
  end

  -- Only proceed if screw is already loaded and lualine is enabled
  local config = get_config()
  local lualine_config = config.lualine or {}
  if not lualine_config.enabled then
    return ""
  end

  -- Check if storage is initialized to avoid triggering file creation
  local storage = require("screw.notes.storage")
  if not storage.is_initialized() then
    -- No line notes without storage
    return ""
  end

  return get_cached("line_notes", function()
    local manager = get_notes_manager()
    if not manager then
      return ""
    end

    local notes = manager.get_current_line_notes()
    if #notes == 0 then
      return ""
    end

    local config = get_lualine_config()
    local component_config = config.components and config.components.line_notes or {}

    if not component_config.enabled then
      return ""
    end

    -- Use the first note (highest priority)
    local note = notes[1]

    local data = {
      state = note.state,
      cwe = note.cwe or "",
      severity = note.severity or "",
      count = #notes,
    }

    return format_component("line_notes", data)
  end)
end

--- Collaboration Status Component
--- Shows collaboration mode status
---@return string
function M.screw_collab()
  -- Return empty unless explicitly enabled via external initialization
  -- This prevents any automatic loading when lualine calls this function
  if not package.loaded["screw"] then
    return ""
  end

  -- Only proceed if screw is already loaded and lualine is enabled
  local config = get_config()
  local lualine_config = config.lualine or {}
  if not lualine_config.enabled then
    return ""
  end

  return get_cached("collab_status", function()
    local collaboration = get_collaboration()
    local config = get_lualine_config()
    local component_config = config.components and config.components.collaboration or {}

    if not component_config.enabled then
      return ""
    end

    local is_online = false
    local mode = "local"

    if collaboration and collaboration.get_status then
      local status = collaboration.get_status()

      -- If collaboration mode is "collaborative", check if we're actually connected
      if status.mode == "collaborative" then
        -- For collaborative mode, check the backend connection status
        local storage_success, storage = pcall(require, "screw.notes.storage")
        if storage_success and storage.get_backend then
          local backend = storage.get_backend()
          if backend and backend.is_connected and backend:is_connected() then
            is_online = true
            mode = "online"
          else
            is_online = false
            mode = "offline"
          end
        else
          -- Fallback: assume offline if we can't check backend
          is_online = false
          mode = "offline"
        end
      else
        -- Local mode
        mode = "local"
        is_online = false
      end
    end

    local data = {
      mode = mode,
      is_online = is_online,
      is_local = mode == "local",
      status = mode, -- Add status field to match %{status_icon} format
    }

    return format_component("collaboration", data)
  end)
end

--- Setup function for lualine integration
---@param config? table Optional configuration override
function M.setup(config)
  if not has_lualine() then
    return
  end

  if not is_enabled() then
    return
  end

  -- Register event handlers for cache invalidation
  local group = vim.api.nvim_create_augroup("ScrewLualine", { clear = true })

  -- Invalidate caches when notes change
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "ScrewNote*",
    callback = invalidate_caches,
  })

  -- Invalidate line notes cache when cursor moves
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function()
      cache.line_notes.timestamp = 0
    end,
  })

  -- Invalidate file status cache when buffer changes
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = group,
    callback = function()
      cache.file_status.timestamp = 0
    end,
  })
end

--- Get available components for user configuration
---@return table
function M.get_components()
  return {
    screw_summary = M.screw_summary,
    screw_file_status = M.screw_file_status,
    screw_line_notes = M.screw_line_notes,
    screw_collab = M.screw_collab,
  }
end

--- Check if integration is available
---@return boolean, string?
function M.check_availability()
  if not has_lualine() then
    return false, "lualine.nvim is not installed"
  end

  if not is_enabled() then
    return false, "lualine integration is disabled in configuration"
  end

  return true
end

return M
