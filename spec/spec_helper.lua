-- Test helper functions for screw.nvim
local helpers = {}

-- Mock vim global for testing
_G.vim = {
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
    input = function(prompt)
      return "test_input"
    end,
    isdirectory = function(path)
      return 1  -- Always return true for tests
    end,
  },
  api = {
    nvim_create_buf = function() return 1 end,
    nvim_buf_set_lines = function() end,
    nvim_buf_set_option = function() end,
    nvim_win_set_buf = function() end,
    nvim_get_current_line = function() return "test line" end,
    nvim_win_get_cursor = function() return {1, 0} end,
    nvim_buf_get_name = function() return "/tmp/test.lua" end,
    nvim_buf_line_count = function() return 100 end,
    nvim_win_set_cursor = function() end,
    nvim_create_user_command = function() end,
    nvim_create_augroup = function() return 1 end,
    nvim_create_autocmd = function() end,
    nvim_set_hl = function() end,
    nvim_err_writeln = function() end,
    nvim_buf_get_lines = function() return {"line1", "line2"} end,
    nvim_open_win = function() return 1 end,
    nvim_win_close = function() end,
    nvim_buf_set_keymap = function() end,
    nvim_win_set_option = function() end,
    nvim_command = function() end,
    nvim_exec = function() end,
    nvim_call_function = function() end,
    nvim_get_current_buf = function() return 1 end,
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
    fs_stat = function() return {type = "directory"} end,
    fs_mkdir = function() return true end,
    fs_open = function() return 1 end,
    fs_close = function() return true end,
    fs_write = function() return true end,
    fs_read = function() return "test content" end,
  },
  json = {
    encode = function(obj) return "{}" end,
    decode = function(str) return {} end,
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
  tbl_extend = function(behavior, ...)
    local result = {}
    for _, tbl in ipairs({...}) do
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
  notify = function() end,
  schedule = function(fn) fn() end,
  defer_fn = function(fn) fn() end,
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
  -- For now, just reset vim.g
  vim.g = {}
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
end

return helpers