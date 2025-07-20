--- Internal configuration for screw.nvim
---
--- This file handles the internal configuration with no nil values,
--- merging user configuration with sensible defaults.
---

local utils = require("screw.utils")

--- Generate default filename with timestamp
---@return string
local function generate_default_filename()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  return "screw_notes_" .. timestamp .. ".json"
end

---@class screw.InternalConfig
local default_config = {
  ---@type "json"|"sqlite"
  storage = {
    ---@type "json"|"sqlite"
    backend = "json",
    ---@type string
    path = "", -- Will be set dynamically
    ---@type string
    filename = "", -- Will be set dynamically
    ---@type boolean
    auto_save = true,
  },
  ---@type table
  ui = {
    ---@type table
    float_window = {
      ---@type number
      width = 80,
      ---@type number
      height = 20,
      ---@type "none"|"single"|"double"|"rounded"|"solid"|"shadow"
      border = "rounded",
      ---@type number
      winblend = 0,
    },
    ---@type table
    highlights = {
      ---@type string
      note_marker = "DiagnosticInfo",
      ---@type string
      vulnerable = "DiagnosticError",
      ---@type string
      not_vulnerable = "DiagnosticOk",
      ---@type string
      todo = "DiagnosticWarn",
      ---@type string
      field_title = "Title",
      ---@type string
      field_info = "Comment",
    },
  },
  ---@type table
  collaboration = {
    ---@type boolean
    enabled = false,
    ---@type string
    database_url = "",
    ---@type number
    sync_interval = 1000,
  },
  ---@type table
  export = {
    ---@type "markdown"|"json"|"csv"
    default_format = "markdown",
    ---@type string
    output_dir = "", -- Will be set dynamically
  },
  ---@type table
  import = {
    ---@type table
    sarif = {
      ---@type "ask"|"skip"|"overwrite"|"merge"
      collision_strategy = "ask",
      ---@type string
      default_author = "sarif-import",
      ---@type boolean
      preserve_metadata = true,
      ---@type boolean
      show_progress = false,
    },
    ---@type boolean
    auto_map_cwe = true,
  },
  ---@type table
  signs = {
    ---@type boolean
    enabled = true,
    ---@type number
    priority = 8,
    ---@type table
    icons = {
      ---@type string
      vulnerable = "🔴",
      ---@type string
      not_vulnerable = "✅",
      ---@type string
      todo = "📝",
      ---@type string
      vulnerable_imported = "🔺",
      ---@type string
      not_vulnerable_imported = "☑️",
      ---@type string
      todo_imported = "📋",
    },
    ---@type table
    colors = {
      ---@type string
      vulnerable = "#f87171",
      ---@type string
      not_vulnerable = "#34d399",
      ---@type string
      todo = "#fbbf24",
      ---@type string
      vulnerable_imported = "#dc2626",
      ---@type string
      not_vulnerable_imported = "#16a34a",
      ---@type string
      todo_imported = "#d97706",
    },
    ---@type table
    keywords = {
      ---@type string[]
      vulnerable = { "VULNERABLE", "FIXME", "BUG", "ISSUE", "VULNERABILITY", "SECURITY", "EXPLOIT" },
      ---@type string[]
      not_vulnerable = { "FALSE POSITIVE", "SECURE", "SAFE", "OK" },
      ---@type string[]
      todo = { "TODO", "INFO", "WARNING", "CHECK", "REVIEW" },
    },
  },
}

local M = {}

--- Validate configuration structure and types
---@param config table
---@return boolean, string?
local function validate_config_structure(config)
  -- Define allowed keys for each section
  local allowed_keys = {
    storage = { "backend", "path", "filename", "auto_save" },
    ui = { "float_window", "highlights" },
    float_window = { "width", "height", "border", "winblend" },
    highlights = { "note_marker", "vulnerable", "not_vulnerable", "todo", "field_title", "field_info" },
    collaboration = { "enabled", "database_url", "sync_interval" },
    export = { "default_format", "output_dir" },
    import = { "sarif", "auto_map_cwe" },
    sarif = { "collision_strategy", "default_author", "preserve_metadata", "show_progress" },
    signs = { "enabled", "priority", "icons", "colors", "keywords" },
    icons = {
      "vulnerable",
      "not_vulnerable",
      "todo",
      "vulnerable_imported",
      "not_vulnerable_imported",
      "todo_imported",
    },
    colors = {
      "vulnerable",
      "not_vulnerable",
      "todo",
      "vulnerable_imported",
      "not_vulnerable_imported",
      "todo_imported",
    },
    keywords = { "vulnerable", "not_vulnerable", "todo" },
  }

  -- Check for unknown keys in main config
  for key in pairs(config) do
    if
      not allowed_keys[key]
      and not vim.tbl_contains({ "storage", "ui", "collaboration", "export", "import", "signs" }, key)
    then
      return false, string.format("Unknown configuration key: '%s'", key)
    end
  end

  -- Check nested sections
  if config.ui then
    if config.ui.float_window then
      for key in pairs(config.ui.float_window) do
        if not vim.tbl_contains(allowed_keys.float_window, key) then
          return false, string.format("Unknown ui.float_window key: '%s'", key)
        end
      end
    end

    if config.ui.highlights then
      for key in pairs(config.ui.highlights) do
        if not vim.tbl_contains(allowed_keys.highlights, key) then
          return false, string.format("Unknown ui.highlights key: '%s'", key)
        end
      end
    end
  end

  -- Check import.sarif section
  if config.import and config.import.sarif then
    for key in pairs(config.import.sarif) do
      if not vim.tbl_contains(allowed_keys.sarif, key) then
        return false, string.format("Unknown import.sarif key: '%s'", key)
      end
    end
  end

  -- Check other sections for unknown keys
  for section, keys in pairs(allowed_keys) do
    if config[section] and type(config[section]) == "table" then
      for key in pairs(config[section]) do
        if not vim.tbl_contains(keys, key) then
          return false, string.format("Unknown %s key: '%s'", section, key)
        end
      end
    end
  end

  return true
end

--- Validate configuration values
---@param config table
---@return boolean, string?
local function validate_config_values(config)
  local validations = {
    -- Storage validations
    { "storage", "table", config.storage },
    {
      "storage.backend",
      function(v)
        return vim.tbl_contains({ "json", "sqlite" }, v)
      end,
      config.storage.backend,
      "must be 'json' or 'sqlite'",
    },
    { "storage.path", "string", config.storage.path },
    { "storage.filename", "string", config.storage.filename },
    { "storage.auto_save", "boolean", config.storage.auto_save },

    -- UI validations
    { "ui", "table", config.ui },
    { "ui.float_window", "table", config.ui.float_window },
    { "ui.float_window.width", { "number", "string" }, config.ui.float_window.width },
    { "ui.float_window.height", { "number", "string" }, config.ui.float_window.height },
    {
      "ui.float_window.border",
      function(v)
        return vim.tbl_contains({ "none", "single", "double", "rounded", "solid", "shadow" }, v)
      end,
      config.ui.float_window.border,
      "must be valid border style",
    },
    { "ui.float_window.winblend", "number", config.ui.float_window.winblend },
    { "ui.highlights", "table", config.ui.highlights },
    { "ui.highlights.note_marker", "string", config.ui.highlights.note_marker },
    { "ui.highlights.vulnerable", "string", config.ui.highlights.vulnerable },
    { "ui.highlights.not_vulnerable", "string", config.ui.highlights.not_vulnerable },
    { "ui.highlights.todo", "string", config.ui.highlights.todo },
    { "ui.highlights.field_title", "string", config.ui.highlights.field_title },
    { "ui.highlights.field_info", "string", config.ui.highlights.field_info },

    -- Collaboration validations
    { "collaboration", "table", config.collaboration },
    { "collaboration.enabled", "boolean", config.collaboration.enabled },
    { "collaboration.database_url", "string", config.collaboration.database_url },
    { "collaboration.sync_interval", "number", config.collaboration.sync_interval },

    -- Export validations
    { "export", "table", config.export },
    {
      "export.default_format",
      function(v)
        return vim.tbl_contains({ "markdown", "json", "csv" }, v)
      end,
      config.export.default_format,
      "must be 'markdown', 'json', or 'csv'",
    },
    { "export.output_dir", "string", config.export.output_dir },

    -- Import validations
    { "import", "table", config.import },
    { "import.sarif", "table", config.import.sarif },
    {
      "import.sarif.collision_strategy",
      function(v)
        return vim.tbl_contains({ "ask", "skip", "overwrite", "merge" }, v)
      end,
      config.import.sarif.collision_strategy,
      "must be 'ask', 'skip', 'overwrite', or 'merge'",
    },
    { "import.sarif.default_author", "string", config.import.sarif.default_author },
    { "import.sarif.preserve_metadata", "boolean", config.import.sarif.preserve_metadata },
    { "import.sarif.show_progress", "boolean", config.import.sarif.show_progress },
    { "import.auto_map_cwe", "boolean", config.import.auto_map_cwe },

    -- Signs validations
    { "signs", "table", config.signs },
    { "signs.enabled", "boolean", config.signs.enabled },
    { "signs.priority", "number", config.signs.priority },
    { "signs.icons", "table", config.signs.icons },
    { "signs.icons.vulnerable", "string", config.signs.icons.vulnerable },
    { "signs.icons.not_vulnerable", "string", config.signs.icons.not_vulnerable },
    { "signs.icons.todo", "string", config.signs.icons.todo },
    { "signs.icons.vulnerable_imported", "string", config.signs.icons.vulnerable_imported },
    { "signs.icons.not_vulnerable_imported", "string", config.signs.icons.not_vulnerable_imported },
    { "signs.icons.todo_imported", "string", config.signs.icons.todo_imported },
    { "signs.colors", "table", config.signs.colors },
    { "signs.colors.vulnerable", "string", config.signs.colors.vulnerable },
    { "signs.colors.not_vulnerable", "string", config.signs.colors.not_vulnerable },
    { "signs.colors.todo", "string", config.signs.colors.todo },
    { "signs.colors.vulnerable_imported", "string", config.signs.colors.vulnerable_imported },
    { "signs.colors.not_vulnerable_imported", "string", config.signs.colors.not_vulnerable_imported },
    { "signs.colors.todo_imported", "string", config.signs.colors.todo_imported },
    { "signs.keywords", "table", config.signs.keywords },
    { "signs.keywords.vulnerable", "table", config.signs.keywords.vulnerable },
    { "signs.keywords.not_vulnerable", "table", config.signs.keywords.not_vulnerable },
    { "signs.keywords.todo", "table", config.signs.keywords.todo },
  }

  for _, validation in ipairs(validations) do
    local name, validator, value, message = validation[1], validation[2], validation[3], validation[4]

    if type(validator) == "string" then
      if type(value) ~= validator then
        return false, string.format("Invalid type for '%s': expected %s, got %s", name, validator, type(value))
      end
    elseif type(validator) == "table" then
      local valid = false
      for _, valid_type in ipairs(validator) do
        if type(value) == valid_type then
          valid = true
          break
        end
      end
      if not valid then
        return false,
          string.format(
            "Invalid type for '%s': expected %s, got %s",
            name,
            table.concat(validator, " or "),
            type(value)
          )
      end
    elseif type(validator) == "function" then
      if not validator(value) then
        return false, string.format("Invalid value for '%s': %s", name, message or "validation failed")
      end
    end
  end

  -- Additional range validations
  if config.ui.float_window.winblend < 0 or config.ui.float_window.winblend > 100 then
    return false, "ui.float_window.winblend must be between 0 and 100"
  end

  if config.collaboration.sync_interval <= 0 then
    return false, "collaboration.sync_interval must be greater than 0"
  end

  return true
end

--- Get user configuration from vim.g or function
---@return screw.Config
local function get_user_config()
  local user_config = vim.g.screw_nvim

  if type(user_config) == "function" then
    local success, result = pcall(user_config)
    if success and type(result) == "table" then
      return result
    else
      utils.error("screw_nvim configuration function failed: " .. tostring(result))
      return {}
    end
  elseif type(user_config) == "table" then
    return user_config
  else
    return {}
  end
end

--- Create and validate the internal configuration
---@param override_config? screw.Config
---@return screw.InternalConfig
function M.create_config(override_config)
  -- Get user configuration from vim.g or override
  local user_config = override_config or get_user_config()

  -- Validate user configuration structure
  local structure_valid, structure_error = validate_config_structure(user_config)
  if not structure_valid then
    error("Invalid screw.nvim configuration: " .. structure_error)
  end

  -- Deep merge with defaults
  local config = vim.tbl_deep_extend("force", default_config, user_config)

  -- Set dynamic defaults
  if config.storage.path == "" then
    config.storage.path = utils.get_project_root()
  end

  if config.storage.filename == "" then
    config.storage.filename = "" -- Let the storage backend handle filename detection
  end

  if config.export.output_dir == "" then
    config.export.output_dir = utils.get_project_root()
  end

  -- Validate final configuration
  local values_valid, values_error = validate_config_values(config)
  if not values_valid then
    error("Invalid screw.nvim configuration: " .. values_error)
  end

  return config
end

return M
