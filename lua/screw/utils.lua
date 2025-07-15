--- Utility functions for screw.nvim
---
--- This module contains helper functions used throughout the plugin.
---

local M = {}

--- Generate a unique identifier
---@return string
function M.generate_id()
  return tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
end

--- Get ISO 8601 timestamp
---@return string
function M.get_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

--- Get current user name
---@return string
function M.get_author()
  -- Try multiple environment variables
  local author = vim.env.USER or vim.env.USERNAME or vim.env.LOGNAME

  -- Fallback to system methods if env vars don't work
  if not author or author == "" then
    local success, result = pcall(function()
      return vim.fn.system("whoami"):gsub("%s+", "")
    end)
    if success and result and result ~= "" then
      author = result
    end
  end

  -- Final fallback
  if not author or author == "" then
    author = "unknown"
  end

  return tostring(author)
end

--- Get relative path from project root
---@param filepath string
---@return string
function M.get_relative_path(filepath)
  local project_root = M.get_project_root()
  -- Ensure both paths are absolute and normalized
  local abs_filepath = vim.fn.fnamemodify(filepath, ":p")
  local abs_project_root = vim.fn.fnamemodify(project_root, ":p")

  -- Remove trailing slash from project root if present
  abs_project_root = abs_project_root:gsub("/$", "")

  if abs_filepath:sub(1, #abs_project_root) == abs_project_root then
    local relative = abs_filepath:sub(#abs_project_root + 2) -- Remove leading slash
    return relative == "" and "." or relative
  end
  return abs_filepath -- Return absolute if outside project
end

--- Get absolute path from relative path (relative to project root)
---@param relative_path string
---@return string
function M.get_absolute_path(relative_path)
  if relative_path == "." then
    return M.get_project_root()
  end

  -- Handle tilde expansion first
  if relative_path:sub(1, 1) == "~" then
    return vim.fn.fnamemodify(relative_path, ":p")
  end

  -- If already absolute, return as-is
  if relative_path:sub(1, 1) == "/" or relative_path:match("^%a:") then
    return relative_path
  end

  -- Join with project root
  local project_root = M.get_project_root()
  return vim.fn.fnamemodify(project_root .. "/" .. relative_path, ":p")
end

--- Validate CWE identifier
---@param cwe string
---@return boolean
function M.is_valid_cwe(cwe)
  if not cwe or type(cwe) ~= "string" then
    return false
  end
  return cwe:match("^CWE%-[0-9]+$") ~= nil
end

--- Validate vulnerability state
---@param state string
---@return boolean
function M.is_valid_state(state)
  return vim.tbl_contains({ "vulnerable", "not_vulnerable", "todo" }, state)
end

--- Validate severity level
---@param severity string
---@return boolean
function M.is_valid_severity(severity)
  return vim.tbl_contains({ "high", "medium", "low", "info" }, severity)
end

--- Ensure directory exists
---@param path string
---@return boolean
function M.ensure_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    return vim.fn.mkdir(path, "p") == 1
  end
  return true
end

--- Read file contents
---@param path string
---@return string?
function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

--- Write file contents
---@param path string
---@param content string
---@return boolean
function M.write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    return false
  end
  file:write(content)
  file:close()
  return true
end

--- Deep copy table
---@param orig table
---@return table
function M.deep_copy(orig)
  local copy
  if type(orig) == "table" then
    copy = {}
    for k, v in pairs(orig) do
      copy[M.deep_copy(k)] = M.deep_copy(v)
    end
    setmetatable(copy, M.deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

--- Check if file exists
---@param path string
---@return boolean
function M.file_exists(path)
  return vim.fn.filereadable(path) == 1
end

--- Escape special characters for pattern matching
---@param text string
---@return string
function M.escape_pattern(text)
  return text:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
end

--- Truncate text to specified length
---@param text string
---@param max_length number
---@return string
function M.truncate(text, max_length)
  if #text <= max_length then
    return text
  end
  return text:sub(1, max_length - 3) .. "..."
end

--- Split string by delimiter
---@param str string
---@param delimiter string
---@return string[]
function M.split(str, delimiter)
  local result = {}
  local pattern = "([^" .. delimiter .. "]+)"
  for match in str:gmatch(pattern) do
    table.insert(result, match)
  end
  return result
end

--- Join table elements with delimiter
---@param tbl string[]
---@param delimiter string
---@return string
function M.join(tbl, delimiter)
  return table.concat(tbl, delimiter)
end

--- Get buffer info for current position
---@return table
function M.get_buffer_info()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  return {
    bufnr = bufnr,
    filepath = filepath,
    line_number = cursor[1],
    column = cursor[2],
    relative_path = M.get_relative_path(filepath),
  }
end

--- Show notification message
---@param msg string
---@param level number? vim.log.levels
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify("[screw.nvim] " .. msg, level)
end

--- Show error message
---@param msg string
function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

--- Show warning message
---@param msg string
function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

--- Show info message
---@param msg string
function M.info(msg)
  M.notify(msg, vim.log.levels.INFO)
end

--- Get project root directory
---@return string
function M.get_project_root()
  -- Return cached value if available
  if vim.g.screw_project_root then
    return vim.g.screw_project_root
  end

  -- Try to find git root by going up the directory tree from current file
  local current_file = vim.fn.expand("%:p")
  if current_file and current_file ~= "" then
    local dir = vim.fn.fnamemodify(current_file, ":h")
    while dir and dir ~= "/" and dir ~= "." do
      if vim.fn.isdirectory(dir .. "/.git") == 1 then
        vim.g.screw_project_root = dir
        return dir
      end
      local parent = vim.fn.fnamemodify(dir, ":h")
      if parent == dir then break end
      dir = parent
    end
  end

  -- Try git command from current working directory
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error == 0 and git_root ~= "" and git_root ~= "." then
    vim.g.screw_project_root = git_root
    return git_root
  end

  -- Fall back to the initial working directory
  local nvim_cwd = vim.fn.getcwd()
  vim.g.screw_project_root = nvim_cwd
  return nvim_cwd
end

return M