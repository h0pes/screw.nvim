-- Test helper functions for screw.nvim
local helpers = {}

-- Mock vim global for testing with extended functions
_G.vim = {
  g = {},
  v = {},
  opt = {
    rtp = {
      append = function() end,
    },
  },
  cmd = function() end,
  health = {
    error = function(msg)
      print("Health error: " .. msg)
    end,
    warn = function(msg)
      print("Health warn: " .. msg)
    end,
    info = function(msg)
      print("Health info: " .. msg)
    end,
    ok = function(msg)
      print("Health ok: " .. msg)
    end,
  },
  log = {
    levels = {
      ERROR = 1,
      WARN = 2,
      INFO = 3,
      DEBUG = 4,
    },
  },
  api = {
    nvim_create_autocmd = function() end,
    nvim_create_user_command = function() end,
  },
  tbl_contains = function(table, value)
    for _, item in ipairs(table) do
      if item == value then
        return true
      end
    end
    return false
  end,
  tbl_deep_extend = function(behavior, ...)
    local result = {}
    local function deep_extend(dst, src)
      for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
          dst[k] = deep_extend(dst[k], v)
        else
          dst[k] = v
        end
      end
      return dst
    end

    for i = 1, select("#", ...) do
      local tbl = select(i, ...)
      if tbl then
        result = deep_extend(result, tbl)
      end
    end
    return result
  end,
  split = function(str, delimiter)
    if not str or not delimiter then
      return {}
    end
    local result = {}
    local pattern = "(.-)" .. delimiter
    local last_pos = 1
    for part in str:gmatch(pattern) do
      table.insert(result, part)
      last_pos = last_pos + #part + #delimiter
    end
    table.insert(result, str:sub(last_pos))
    return result
  end,
  tbl_isempty = function(t)
    return next(t) == nil
  end,
  inspect = function(obj)
    if type(obj) == "table" then
      local str = "{"
      for k, v in pairs(obj) do
        str = str .. tostring(k) .. "=" .. tostring(v) .. ", "
      end
      str = str:sub(1, -3) .. "}"
      return str
    else
      return tostring(obj)
    end
  end,
  deepcopy = function(orig)
    local copy
    if type(orig) == "table" then
      copy = {}
      for k, v in pairs(orig) do
        copy[k] = vim.deepcopy(v)
      end
    else
      copy = orig
    end
    return copy
  end,
  fn = {
    stdpath = function(type)
      if type == "data" then
        return "/tmp/nvim-test"
      elseif type == "config" then
        return "/tmp/nvim-test/config"
      end
      return "/tmp/nvim-test"
    end,
    expand = function(path)
      return path:gsub("%%", "/tmp/nvim-test")
    end,
    fnamemodify = function(path, mods)
      if mods == ":p" then
        return path:sub(1, 1) == "/" and path or "/tmp/nvim-test/" .. path
      elseif mods == ":h" then
        return path:match("(.*/)")
      elseif mods == ":t" then
        return path:match("([^/]+)$")
      elseif mods == ":~:." then
        -- Convert absolute path to relative path from current working directory
        local cwd = vim.fn.getcwd()
        if path:sub(1, #cwd) == cwd then
          local relative = path:sub(#cwd + 2) -- +2 to skip the trailing slash
          return relative
        end
        return path
      end
      return path
    end,
    getcwd = function()
      return "/tmp/nvim-test"
    end,
    glob = function(pattern)
      return {}
    end,
    fnameescape = function(path)
      return path:gsub(" ", "\\ ")
    end,
    exists = function()
      return 1
    end,
    mkdir = function()
      return 1
    end,
    writefile = function()
      return 0
    end,
    readfile = function()
      return {}
    end,
    delete = function()
      return 0
    end,
    system = function(cmd)
      if cmd:match("whoami") then
        return "testuser"
      end
      return ""
    end,
    shellescape = function(str)
      return "'" .. str:gsub("'", "'\"'\"'") .. "'"
    end,
    input = function(prompt)
      return "test_input"
    end,
    isdirectory = function(path)
      return 1 -- Always return true for tests
    end,
    filereadable = function(path)
      return 1 -- Always return true for tests
    end,
  },
  api = {
    nvim_create_buf = function()
      return 1
    end,
    nvim_buf_set_lines = function() end,
    nvim_buf_set_option = function() end,
    nvim_win_set_buf = function() end,
    nvim_get_current_line = function()
      return "test line"
    end,
    nvim_win_get_cursor = function(win)
      -- Return current cursor position for any window (including 0 for current)
      return { 1, 0 }
    end,
    nvim_buf_get_name = function()
      return "/tmp/test.lua"
    end,
    nvim_buf_line_count = function()
      return 100
    end,
    nvim_win_set_cursor = function() end,
    nvim_create_user_command = function() end,
    nvim_create_augroup = function()
      return 1
    end,
    nvim_create_autocmd = function() end,
    nvim_set_hl = function() end,
    nvim_err_writeln = function() end,
    nvim_buf_get_lines = function()
      return { "line1", "line2" }
    end,
    nvim_open_win = function()
      return 1
    end,
    nvim_win_close = function() end,
    nvim_buf_set_keymap = function() end,
    nvim_win_set_option = function() end,
    nvim_command = function() end,
    nvim_exec = function() end,
    nvim_call_function = function() end,
    nvim_get_current_buf = function()
      return 1
    end,
    nvim_list_bufs = function()
      return { 1, 2, 3 }
    end,
    nvim_buf_is_valid = function()
      return true
    end,
    nvim_buf_is_loaded = function()
      return true
    end,
    nvim_exec_autocmds = function()
      -- Mock autocmd execution
    end,
    nvim_create_namespace = function(name)
      return 123 -- Return a mock namespace ID
    end,
  },
  keymap = {
    set = function() end,
    del = function() end,
  },
  cmd = function() end,
  g = {},
  env = {
    USER = "testuser",
    HOME = "/tmp/nvim-test",
  },
  loop = {
    new_timer = function()
      return {
        start = function() end,
        stop = function() end,
        close = function() end,
      }
    end,
    now = function()
      return os.time() * 1000 -- Return milliseconds timestamp
    end,
    fs_stat = function()
      return { type = "directory" }
    end,
    fs_mkdir = function()
      return true
    end,
    fs_open = function()
      return 1
    end,
    fs_close = function()
      return true
    end,
    fs_write = function()
      return true
    end,
    fs_read = function()
      return "test content"
    end,
  },
  json = {
    encode = function(obj)
      -- Check for invalid objects that can't be encoded (like functions)
      local function has_function(t)
        if type(t) ~= "table" then
          return false
        end
        for k, v in pairs(t) do
          if type(v) == "function" then
            return true
          elseif type(v) == "table" then
            if has_function(v) then
              return true
            end
          end
        end
        return false
      end

      if type(obj) == "table" and has_function(obj) then
        error("Cannot encode function to JSON")
      end

      -- Store the encoded object for decode to use - this is the simplest approach
      _G._test_encoded_obj = obj
      -- Return a simple JSON string for logging/debugging
      return '{"version":"2.1.0","runs":[{"tool":{"driver":{"name":"screw.nvim"}},"results":[]}]}'
    end,
    decode = function(str)
      -- PRIORITIZE: Return the actual object that was passed to encode
      -- This is the most reliable approach for tests
      if _G._test_encoded_obj then
        local obj = _G._test_encoded_obj
        -- For HTTP tests, keep the object available for multiple decode calls
        -- Only clear for SARIF tests (which have version field)
        if obj.version == "2.1.0" then
          _G._test_encoded_obj = nil
        end
        return obj
      end

      -- Fallback: Pattern-based JSON parsing
      if type(str) == "string" then
        -- Handle local notes file format (mode detector tests)
        if str:match('"notes":%s*%[') then
          local success, result = pcall(function()
            -- Simple notes array parsing
            local notes = {}
            for note_json in str:gmatch('{"id":%s*"[^"]*"}') do
              table.insert(notes, { id = note_json:match('"id":%s*"([^"]*)') })
            end
            return { notes = notes }
          end)
          if success then
            return result
          end
        end

        -- Handle common HTTP API response patterns
        if str:match('"note"') and str:match('"id"') then
          local id = str:match('"id":%s*"([^"]*)')
          return { note = { id = id or "test-id" } }
        elseif str:match('"status"') then
          return { status = "ok" }
        elseif str:match('"success"') then
          return { success = true }
        elseif str:match('"total_notes"') then
          return { total_notes = 42, active_users = 3 }
        elseif str == "invalid json" or str == "invalid json content" then
          -- For tests that expect JSON decode to fail
          error("invalid JSON")
        end
      end

      return {}
    end,
  },
  split = function(str, sep)
    local result = {}
    for match in (str .. sep):gmatch("(.-)" .. sep) do
      table.insert(result, match)
    end
    return result
  end,
  tbl_contains = function(tbl, value)
    for _, v in ipairs(tbl) do
      if v == value then
        return true
      end
    end
    return false
  end,
  tbl_keys = function(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
      table.insert(keys, k)
    end
    return keys
  end,
  tbl_extend = function(behavior, ...)
    local result = {}
    for _, tbl in ipairs({ ... }) do
      for k, v in pairs(tbl) do
        result[k] = v
      end
    end
    return result
  end,
  list_slice = function(list, start, finish)
    local result = {}
    for i = start, finish or #list do
      table.insert(result, list[i])
    end
    return result
  end,
  notify = function(message, level, opts) end,
  schedule = function(fn)
    fn()
  end,
  schedule_wrap = function(fn)
    return function(...)
      fn(...)
    end
  end,
  log = {
    levels = {
      ERROR = 1,
      WARN = 2,
      INFO = 3,
      DEBUG = 4,
    },
  },
  defer_fn = function(fn)
    fn()
  end,
}

-- Helper to create a mock note
function helpers.create_mock_note(overrides)
  local note = {
    id = "test-note-123",
    file_path = "test.lua",
    line_number = 1,
    author = "testuser",
    timestamp = "2024-01-01T00:00:00Z",
    comment = "Test comment",
    description = "Test description",
    cwe = "CWE-79",
    state = "vulnerable",
    severity = "high",
    replies = {},
  }

  if overrides then
    for k, v in pairs(overrides) do
      note[k] = v
    end
  end

  return note
end

-- Helper to create multiple mock notes
function helpers.create_mock_notes(count)
  local notes = {}
  for i = 1, count do
    local note = helpers.create_mock_note({
      id = "test-note-" .. i,
      line_number = i,
      comment = "Test comment " .. i,
    })
    table.insert(notes, note)
  end
  return notes
end

-- Helper to clean up test files
function helpers.cleanup_test_files()
  -- In real tests, this would clean up any test files
  -- For now, just reset vim.g and test state
  vim.g = {}
  _G._test_encoded_obj = nil
end

-- Helper to setup test environment
function helpers.setup_test_env()
  helpers.cleanup_test_files()
  -- Reset any global state
  package.loaded["screw"] = nil
  package.loaded["screw.config"] = nil
  package.loaded["screw.utils"] = nil
  package.loaded["screw.notes.manager"] = nil
  package.loaded["screw.notes.storage"] = nil
  package.loaded["screw.import.sarif"] = nil
  package.loaded["screw.import.init"] = nil

  -- Create mock storage module that will be used by imports
  local mock_backend = {
    config = {
      auto_save = true,
    },
    save_note = function(note)
      return true
    end,
    get_all_notes = function()
      return {}
    end,
    force_save = function()
      return true
    end,
  }

  package.loaded["screw.notes.storage"] = {
    get_all_notes = function()
      return {}
    end,
    save_note = function(note)
      return true
    end,
    get_storage_stats = function()
      return {}
    end,
    force_save = function()
      return true
    end,
    get_backend = function()
      return mock_backend
    end,
  }

  -- Reinitialize configuration for tests
  local screw_config = require("screw.config")
  screw_config.setup({
    storage = {
      backend = "json",
      path = "/tmp/screw_test",
      filename = "test_notes.json",
    },
    export = {
      default_format = "markdown",
      output_dir = "/tmp/screw_test/exports",
    },
  })
end

return helpers
