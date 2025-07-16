--- Sign management for screw.nvim
---
--- This module handles placing and removing signs in the signcolumn
--- to provide visual indicators for security notes.
---

local utils = require("screw.utils")
local config = require("screw.config")

local M = {}

-- Namespace for screw signs
M.namespace = vim.api.nvim_create_namespace("screw_signs")

-- Sign priority levels for multiple notes per line
local SIGN_PRIORITY = {
  vulnerable = 3, -- Highest priority
  todo = 2, -- Medium priority
  not_vulnerable = 1, -- Lowest priority
}

-- Track signs by buffer and line for efficient updates
local signs_by_buffer = {}

--- Initialize sign definitions and highlight groups
function M.setup()
  local signs_config = config.get_option("signs")

  if not signs_config.enabled then
    return
  end

  -- Define highlight groups
  M.setup_highlights()

  -- Define sign types
  M.setup_sign_definitions()

  -- Set up autocommands for automatic sign management
  M.setup_autocommands()
end

--- Setup highlight groups for signs
function M.setup_highlights()
  local signs_config = config.get_option("signs")

  -- Define highlight groups if they don't exist
  vim.api.nvim_set_hl(0, "ScrewSignVulnerable", {
    fg = signs_config.colors.vulnerable,
    default = true,
  })

  vim.api.nvim_set_hl(0, "ScrewSignNotVulnerable", {
    fg = signs_config.colors.not_vulnerable,
    default = true,
  })

  vim.api.nvim_set_hl(0, "ScrewSignTodo", {
    fg = signs_config.colors.todo,
    default = true,
  })
end

--- Setup sign definitions
function M.setup_sign_definitions()
  local signs_config = config.get_option("signs")

  vim.fn.sign_define("ScrewVulnerable", {
    text = signs_config.icons.vulnerable,
    texthl = "ScrewSignVulnerable",
    priority = signs_config.priority,
  })

  vim.fn.sign_define("ScrewNotVulnerable", {
    text = signs_config.icons.not_vulnerable,
    texthl = "ScrewSignNotVulnerable",
    priority = signs_config.priority,
  })

  vim.fn.sign_define("ScrewTodo", {
    text = signs_config.icons.todo,
    texthl = "ScrewSignTodo",
    priority = signs_config.priority,
  })
end

--- Setup autocommands for automatic sign placement
function M.setup_autocommands()
  local signs_config = config.get_option("signs")

  if not signs_config.enabled then
    return
  end

  local group = vim.api.nvim_create_augroup("ScrewSigns", { clear = true })

  -- Place signs when buffer is loaded or entered
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      if M.should_place_signs(bufnr) then
        M.place_buffer_signs(bufnr)
      end
    end,
  })

  -- Clean up signs when buffer is deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      M.clear_buffer_signs(bufnr)
      signs_by_buffer[bufnr] = nil
    end,
  })
end

--- Check if signs should be placed for a buffer
---@param bufnr number
---@return boolean
function M.should_place_signs(bufnr)
  -- Only place signs for regular files
  local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
  if buftype ~= "" then
    return false
  end

  -- Check if buffer has a valid file path
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath or filepath == "" then
    return false
  end

  return true
end

--- Place signs for all notes in a buffer
---@param bufnr number
function M.place_buffer_signs(bufnr)
  local signs_config = config.get_option("signs")

  if not signs_config.enabled then
    return
  end

  -- Get notes manager and load notes for this buffer
  local notes_manager = require("screw.notes.manager")
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local relative_path = utils.get_relative_path(filepath)

  -- Get notes for this file
  local all_notes = notes_manager.get_notes()
  local file_notes = {}

  for _, note in ipairs(all_notes) do
    if note.file_path == relative_path then
      table.insert(file_notes, note)
    end
  end

  if #file_notes == 0 then
    return
  end

  -- Clear existing signs for this buffer
  M.clear_buffer_signs(bufnr)

  -- Group notes by line number
  local notes_by_line = {}
  for _, note in ipairs(file_notes) do
    local line = note.line_number
    if not notes_by_line[line] then
      notes_by_line[line] = {}
    end
    table.insert(notes_by_line[line], note)
  end

  -- Place signs for each line with notes
  for line_number, line_notes in pairs(notes_by_line) do
    local sign_state = M.get_priority_state(line_notes)
    M.place_sign(bufnr, line_number, sign_state)
  end
end

--- Get the highest priority state from multiple notes on the same line
---@param notes ScrewNote[]
---@return string
function M.get_priority_state(notes)
  local max_priority = 0
  local priority_state = "todo"

  for _, note in ipairs(notes) do
    local priority = SIGN_PRIORITY[note.state] or 0
    if priority > max_priority then
      max_priority = priority
      priority_state = note.state
    end
  end

  return priority_state
end

--- Place a sign at specific line
---@param bufnr number
---@param line_number number
---@param state string
function M.place_sign(bufnr, line_number, state)
  local signs_config = config.get_option("signs")

  if not signs_config.enabled then
    return
  end

  local sign_name = M.get_sign_name(state)
  if not sign_name then
    return
  end

  -- Generate unique sign ID
  local sign_id = M.generate_sign_id(bufnr, line_number)

  -- Place the sign
  vim.fn.sign_place(sign_id, "screw", sign_name, bufnr, {
    lnum = line_number,
    priority = signs_config.priority,
  })

  -- Track the sign
  if not signs_by_buffer[bufnr] then
    signs_by_buffer[bufnr] = {}
  end
  signs_by_buffer[bufnr][line_number] = {
    id = sign_id,
    state = state,
  }
end

--- Remove sign from specific line
---@param bufnr number
---@param line_number number
function M.remove_sign(bufnr, line_number)
  if not signs_by_buffer[bufnr] or not signs_by_buffer[bufnr][line_number] then
    return
  end

  local sign_info = signs_by_buffer[bufnr][line_number]
  vim.fn.sign_unplace("screw", { buffer = bufnr, id = sign_info.id })

  signs_by_buffer[bufnr][line_number] = nil
end

--- Clear all signs for a buffer
---@param bufnr number
function M.clear_buffer_signs(bufnr)
  if not signs_by_buffer[bufnr] then
    return
  end

  -- Remove all signs for this buffer
  vim.fn.sign_unplace("screw", { buffer = bufnr })
  signs_by_buffer[bufnr] = {}
end

--- Update signs when a note is added
---@param note ScrewNote
function M.on_note_added(note)
  local signs_config = config.get_option("signs")

  if not signs_config.enabled then
    return
  end

  -- Find the buffer for this file
  local bufnr = M.find_buffer_by_file(note.file_path)
  if not bufnr then
    return
  end

  -- Update signs for this line
  M.update_line_signs(bufnr, note.line_number)
end

--- Update signs when a note is deleted
---@param note ScrewNote
function M.on_note_deleted(note)
  local signs_config = config.get_option("signs")

  if not signs_config.enabled then
    return
  end

  -- Find the buffer for this file
  local bufnr = M.find_buffer_by_file(note.file_path)
  if not bufnr then
    return
  end

  -- Update signs for this line
  M.update_line_signs(bufnr, note.line_number)
end

--- Update signs for a specific line
---@param bufnr number
---@param line_number number
function M.update_line_signs(bufnr, line_number)
  -- Get all notes for this line
  local notes_manager = require("screw.notes.manager")
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local relative_path = utils.get_relative_path(filepath)

  local all_notes = notes_manager.get_notes()
  local line_notes = {}

  for _, note in ipairs(all_notes) do
    if note.file_path == relative_path and note.line_number == line_number then
      table.insert(line_notes, note)
    end
  end

  -- Remove existing sign for this line
  M.remove_sign(bufnr, line_number)

  -- Place new sign if notes exist
  if #line_notes > 0 then
    local sign_state = M.get_priority_state(line_notes)
    M.place_sign(bufnr, line_number, sign_state)
  end
end

--- Find buffer number by file path
---@param file_path string
---@return number?
function M.find_buffer_by_file(file_path)
  local absolute_path = utils.get_absolute_path(file_path)

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_path = vim.api.nvim_buf_get_name(bufnr)
      if buf_path == absolute_path then
        return bufnr
      end
    end
  end

  return nil
end

--- Get sign name for state
---@param state string
---@return string?
function M.get_sign_name(state)
  local sign_map = {
    vulnerable = "ScrewVulnerable",
    not_vulnerable = "ScrewNotVulnerable",
    todo = "ScrewTodo",
  }

  return sign_map[state]
end

--- Generate unique sign ID
---@param bufnr number
---@param line_number number
---@return number
function M.generate_sign_id(bufnr, line_number)
  -- Use buffer and line to create unique ID
  return bufnr * 10000 + line_number
end

--- Refresh all signs (useful for config changes)
function M.refresh_all_signs()
  local signs_config = config.get_option("signs")

  if not signs_config.enabled then
    M.clear_all_signs()
    return
  end

  -- Redefine signs with new config
  M.setup_highlights()
  M.setup_sign_definitions()

  -- Refresh signs for all loaded buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and M.should_place_signs(bufnr) then
      M.place_buffer_signs(bufnr)
    end
  end
end

--- Clear all signs from all buffers
function M.clear_all_signs()
  for bufnr, _ in pairs(signs_by_buffer) do
    M.clear_buffer_signs(bufnr)
  end
  signs_by_buffer = {}
end

return M
