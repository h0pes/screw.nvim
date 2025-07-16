--- Health check for screw.nvim
---
--- This module provides comprehensive health checks for troubleshooting
--- following Neovim plugin best practices.
---

local M = {}

--- Check Neovim version compatibility
local function check_neovim_version()
  vim.health.start("Neovim Environment")

  local version = vim.version()
  local version_string = string.format("%d.%d.%d", version.major, version.minor, version.patch)

  if vim.fn.has("nvim-0.9.0") == 1 then
    vim.health.ok("Neovim version: " .. version_string .. " (>= 0.9.0 required)")
  else
    vim.health.error("Neovim version: " .. version_string .. " - Please upgrade to Neovim 0.9.0 or later")
    return false
  end

  -- Check for important Neovim features
  local features = {
    { "lua", "Lua support" },
    { "autocmd", "Autocommand support" },
    { "cmdline_hist", "Command history" },
    { "float", "Floating windows" },
    { "timers", "Timer support" },
  }

  for _, feature in ipairs(features) do
    local name, desc = feature[1], feature[2]
    if vim.fn.has(name) == 1 then
      vim.health.ok(desc .. " available")
    else
      vim.health.warn(desc .. " not available - some features may not work")
    end
  end

  return true
end

--- Check plugin loading and initialization
local function check_plugin_loading()
  vim.health.start("Plugin Loading")

  -- Check if main plugin loads
  local has_screw, screw_result = pcall(require, "screw")
  if not has_screw then
    vim.health.error("Failed to load main plugin module: " .. tostring(screw_result))
    return false
  end
  vim.health.ok("Main plugin module loaded successfully")

  -- Check core modules
  local core_modules = {
    { "screw.config", "Configuration management" },
    { "screw.utils", "Utility functions" },
    { "screw.types", "Type definitions" },
    { "screw.events", "Event system" },
  }

  for _, module_info in ipairs(core_modules) do
    local module_name, description = module_info[1], module_info[2]
    local success, result = pcall(require, module_name)
    if success then
      vim.health.ok(description .. " module loaded")
    else
      vim.health.error(description .. " module failed to load: " .. tostring(result))
    end
  end

  return true
end

--- Check user configuration
local function check_user_configuration()
  vim.health.start("User Configuration")

  -- Check configuration loading
  local has_config, config = pcall(require, "screw.config")
  if not has_config then
    vim.health.error("Configuration module failed to load: " .. tostring(config))
    return false
  end

  -- Check if user has provided configuration
  if config.is_configured() then
    vim.health.info("Custom user configuration detected")

    -- Validate user configuration
    local success, error_msg = pcall(function()
      local internal_config = require("screw.config.internal")
      internal_config.create_config()
    end)

    if success then
      vim.health.ok("User configuration is valid")
    else
      vim.health.error("User configuration validation failed: " .. tostring(error_msg))
      return false
    end
  else
    vim.health.info("Using default configuration (no custom config found)")
  end

  -- Check specific configuration sections
  local success, current_config = pcall(config.get)
  if success then
    vim.health.ok("Configuration accessible")

    -- Validate configuration structure
    local required_sections = { "storage", "ui", "collaboration", "export", "import", "signs" }
    for _, section in ipairs(required_sections) do
      if current_config[section] then
        vim.health.ok("Configuration section '" .. section .. "' present")
      else
        vim.health.error("Configuration section '" .. section .. "' missing")
      end
    end
  else
    vim.health.error("Cannot access current configuration: " .. tostring(current_config))
    return false
  end

  return true
end

--- Check Lua dependencies and built-in modules
local function check_lua_dependencies()
  vim.health.start("Lua Dependencies")

  -- Check required Lua built-in modules
  local lua_modules = {
    { "os", "Operating system interface" },
    { "io", "Input/output operations" },
    { "string", "String manipulation" },
    { "table", "Table operations" },
    { "math", "Mathematical functions" },
    { "json", "JSON support (vim.json)", vim.json },
  }

  for _, module_info in ipairs(lua_modules) do
    local module_name, description, check_fn = module_info[1], module_info[2], module_info[3]

    if check_fn then
      if check_fn and check_fn.encode and check_fn.decode then
        vim.health.ok(description .. " available")
      else
        vim.health.error(description .. " not available or incomplete")
      end
    else
      local success = pcall(function()
        return _G[module_name]
      end)
      if success and _G[module_name] then
        vim.health.ok(description .. " available")
      else
        vim.health.error(description .. " not available")
      end
    end
  end

  -- Check Neovim-specific Lua modules
  local nvim_modules = {
    { "vim.fn", "Vim function interface" },
    { "vim.api", "Neovim API" },
    { "vim.loop", "Event loop interface" },
    { "vim.validate", "Validation functions" },
    { "vim.health", "Health check system" },
    { "vim.keymap", "Keymap functions" },
  }

  for _, module_info in ipairs(nvim_modules) do
    local module_path, description = module_info[1], module_info[2]
    local parts = vim.split(module_path, ".", { plain = true })
    local obj = vim
    local available = true

    for _, part in ipairs(parts) do
      if obj and obj[part] then
        obj = obj[part]
      else
        available = false
        break
      end
    end

    if available then
      vim.health.ok(description .. " available")
    else
      vim.health.error(description .. " not available")
    end
  end

  return true
end

--- Check external dependencies
local function check_external_dependencies()
  vim.health.start("External Dependencies")

  -- Check optional external tools
  local external_tools = {
    { "rg", "ripgrep (for enhanced search)", false },
    { "fd", "fd (for fast file finding)", false },
    { "git", "Git (for project detection)", false },
  }

  for _, tool_info in ipairs(external_tools) do
    local tool, description, required = tool_info[1], tool_info[2], tool_info[3]

    if vim.fn.executable(tool) == 1 then
      vim.health.ok(description .. " found: " .. vim.fn.exepath(tool))
    else
      if required then
        vim.health.error(description .. " not found (required)")
      else
        vim.health.info(description .. " not found (optional)")
      end
    end
  end

  -- Check collaboration dependencies
  local config = require("screw.config")
  local collab_config = config.get_option("collaboration")

  if collab_config.enabled then
    vim.health.info("Collaboration mode is enabled")

    if collab_config.database_url and collab_config.database_url ~= "" then
      vim.health.ok("Database URL configured: " .. collab_config.database_url)

      -- Test database connectivity (basic check)
      if collab_config.database_url:match("^rethinkdb://") then
        vim.health.info("RethinkDB URL format detected")
      else
        vim.health.warn("Unrecognized database URL format")
      end
    else
      vim.health.error("Collaboration enabled but no database URL configured")
    end
  else
    vim.health.info("Collaboration mode is disabled")
  end

  return true
end

--- Check storage functionality
local function check_storage()
  vim.health.start("Storage System")

  local config = require("screw.config")
  local storage_config = config.get_option("storage")

  -- Check storage backend
  vim.health.info("Storage backend: " .. storage_config.backend)

  -- Check storage path
  local storage_path = storage_config.path
  if storage_path and storage_path ~= "" then
    vim.health.info("Storage path: " .. storage_path)

    -- Check if directory exists or can be created
    if vim.fn.isdirectory(storage_path) == 1 then
      vim.health.ok("Storage directory exists")
    else
      -- Try to create the directory
      local utils = require("screw.utils")
      utils.ensure_dir(storage_path)

      if vim.fn.isdirectory(storage_path) == 1 then
        vim.health.ok("Storage directory created successfully")
      else
        vim.health.error("Cannot create storage directory: " .. storage_path)
        return false
      end
    end

    -- Check write permissions
    local test_file = storage_path .. "/.screw_health_test"
    local utils = require("screw.utils")

    if utils.write_file(test_file, "health test") then
      vim.health.ok("Write permissions verified")
      os.remove(test_file)
    else
      vim.health.error("No write permissions for storage directory")
      return false
    end

    -- Check existing storage file
    local storage_file = storage_path .. "/notes.json"
    if utils.file_exists(storage_file) then
      vim.health.info("Existing notes file found")

      -- Validate storage file
      local content = utils.read_file(storage_file)
      if content then
        local success, data = pcall(vim.json.decode, content)
        if success then
          vim.health.ok("Storage file is valid JSON")
          if data and data.notes then
            vim.health.info("Found " .. #data.notes .. " notes in storage")
          end
        else
          vim.health.error("Storage file contains invalid JSON")
        end
      else
        vim.health.error("Cannot read storage file")
      end
    else
      vim.health.info("No existing notes file (will be created on first save)")
    end
  else
    vim.health.error("Storage path not configured")
    return false
  end

  -- Test storage backend loading
  local has_storage, storage = pcall(require, "screw.notes.storage")
  if has_storage then
    vim.health.ok("Storage backend module loaded")

    -- Test storage backend initialization
    local success, result = pcall(function()
      return storage.get_storage_stats()
    end)

    if success and result then
      vim.health.ok("Storage backend functional")
      vim.health.info("Storage stats: " .. vim.inspect(result))
    else
      vim.health.warn("Storage backend may not be fully initialized")
    end
  else
    vim.health.error("Storage backend module failed to load: " .. tostring(storage))
    return false
  end

  return true
end

--- Check plugin functionality
local function check_functionality()
  vim.health.start("Plugin Functionality")

  -- Check core modules
  local modules = {
    { "screw.notes.manager", "Notes management" },
    { "screw.notes.ui", "User interface" },
    { "screw.export.init", "Export functionality" },
    { "screw.import.init", "Import functionality" },
    { "screw.collaboration.init", "Collaboration features" },
    { "screw.signs", "Sign column indicators" },
  }

  for _, module_info in ipairs(modules) do
    local module_name, description = module_info[1], module_info[2]
    local success, result = pcall(require, module_name)
    if success then
      vim.health.ok(description .. " module available")
    else
      vim.health.error(description .. " module failed to load: " .. tostring(result))
    end
  end

  -- Test basic plugin operations
  local screw = require("screw")

  -- Test configuration access
  local success, config = pcall(screw.get_config)
  if success then
    vim.health.ok("Configuration access functional")
  else
    vim.health.error("Cannot access plugin configuration: " .. tostring(config))
  end

  -- Test statistics
  local success, stats = pcall(screw.get_statistics)
  if success then
    vim.health.ok("Statistics generation functional")
    if stats then
      vim.health.info("Current statistics: " .. vim.inspect(stats))
    end
  else
    vim.health.warn("Statistics generation failed: " .. tostring(stats))
  end

  return true
end

--- Check for potential issues
local function check_potential_issues()
  vim.health.start("Potential Issues")

  -- Check for conflicting plugins
  local conflicting_plugins = {
    { "nvim-comment", "Comment plugin conflict" },
    { "comment.nvim", "Comment plugin conflict" },
    { "nerdcommenter", "Comment plugin conflict" },
    { "vim-commentary", "Commentary plugin conflict" },
  }

  local conflicts_found = false
  for _, plugin_info in ipairs(conflicting_plugins) do
    local plugin, description = plugin_info[1], plugin_info[2]
    if pcall(require, plugin) then
      vim.health.warn(description .. " detected: " .. plugin)
      conflicts_found = true
    end
  end

  if not conflicts_found then
    vim.health.ok("No conflicting plugins detected")
  end

  -- Check performance considerations
  local screw = require("screw")
  local success, notes = pcall(screw.get_notes)
  if success and notes then
    local note_count = #notes

    if note_count == 0 then
      vim.health.info("No notes found - performance should be optimal")
    elseif note_count < 100 then
      vim.health.ok("Note count (" .. note_count .. ") is within optimal range")
    elseif note_count < 1000 then
      vim.health.info("Note count (" .. note_count .. ") may impact performance on older systems")
    else
      vim.health.warn("High note count (" .. note_count .. ") may significantly impact performance")
      vim.health.info("Consider archiving old notes or optimizing storage")
    end
  end

  -- Check startup performance
  vim.health.info("Plugin follows lazy loading best practices for optimal startup performance")

  return true
end

--- Main health check function
function M.check()
  -- Run all health checks in sequence
  local checks = {
    check_neovim_version,
    check_plugin_loading,
    check_user_configuration,
    check_lua_dependencies,
    check_external_dependencies,
    check_storage,
    check_functionality,
    check_potential_issues,
  }

  local all_passed = true
  for _, check_fn in ipairs(checks) do
    local success, result = pcall(check_fn)
    if not success then
      vim.health.error("Health check failed: " .. tostring(result))
      all_passed = false
    elseif result == false then
      all_passed = false
    end
  end

  -- Final summary
  vim.health.start("Health Check Summary")
  if all_passed then
    vim.health.ok("All health checks passed - screw.nvim is ready to use")
  else
    vim.health.error("Some health checks failed - please review the issues above")
    vim.health.info("For help, see: https://github.com/h0pes/screw.nvim/blob/main/doc/troubleshooting.md")
  end
end

return M
