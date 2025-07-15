--- UI module for screw.nvim
---
--- This module handles the float window UI for note creation and viewing.
---

local config = require("screw.config")
local notes_manager = require("screw.notes.manager")
local utils = require("screw.utils")

local M = {}

--- Current float window handles
M.current_win = nil
M.current_buf = nil
M.original_content = nil  -- Track original content for change detection
M.current_mode = nil      -- Track current UI mode: "create", "edit", "view", "select", "reply"
M.current_note = nil      -- Track current note being edited/replied to
M.buffer_info = nil       -- Store original buffer info when creating notes
M.highlight_ns = nil      -- Namespace for highlights

--- Initialize UI
function M.setup()
  M.highlight_ns = vim.api.nvim_create_namespace("ScrewUI")
  M.create_highlight_groups()
end

--- Create highlight groups
function M.create_highlight_groups()
  local highlights = config.get_option("ui.highlights")
  if not highlights then
    return
  end

  -- Set up default highlight groups if they don't exist
  if vim.fn.hlexists("ScrewNoteMarker") == 0 then
    vim.cmd("highlight default link ScrewNoteMarker " .. highlights.note_marker)
  end
  if vim.fn.hlexists("ScrewVulnerable") == 0 then
    vim.cmd("highlight default link ScrewVulnerable " .. highlights.vulnerable)
  end
  if vim.fn.hlexists("ScrewNotVulnerable") == 0 then
    vim.cmd("highlight default link ScrewNotVulnerable " .. highlights.not_vulnerable)
  end
  if vim.fn.hlexists("ScrewTodo") == 0 then
    vim.cmd("highlight default link ScrewTodo " .. highlights.todo)
  end
  if vim.fn.hlexists("ScrewFieldTitle") == 0 then
    vim.cmd("highlight default link ScrewFieldTitle " .. highlights.field_title)
  end
  if vim.fn.hlexists("ScrewFieldInfo") == 0 then
    vim.cmd("highlight default link ScrewFieldInfo " .. highlights.field_info)
  end
end

--- Apply highlights to floating window content
---@param buf number Buffer number
---@param ns_id number Namespace ID
function M.apply_field_highlights(buf, ns_id)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for line_idx, line in ipairs(lines) do
    -- Highlight field titles (lines starting with ##)
    if line:match("^## ") then
      vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx - 1, 0, {
        end_col = #line,
        hl_group = "ScrewFieldTitle",
        priority = 200,
      })
    -- Highlight info lines (Author, File, Line, etc.)
    elseif line:match("^(File|Line|Author|Created|Updated|State|CWE|From|Date|Original Note by): ") then
      local colon_pos = line:find(": ")
      if colon_pos then
        -- Highlight the label part (e.g., "File:")
        vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx - 1, 0, {
          end_col = colon_pos + 1,
          hl_group = "ScrewFieldInfo",
          priority = 200,
        })
      end
    -- Highlight main title (lines starting with #)
    elseif line:match("^# ") then
      vim.api.nvim_buf_set_extmark(buf, ns_id, line_idx - 1, 0, {
        end_col = #line,
        hl_group = "ScrewFieldTitle",
        priority = 200,
      })
    end
  end
end

--- Check if buffer content has changed
---@return boolean
function M.has_unsaved_changes()
  if not M.current_buf or not vim.api.nvim_buf_is_valid(M.current_buf) or not M.original_content then
    return false
  end

  local current_lines = vim.api.nvim_buf_get_lines(M.current_buf, 0, -1, false)
  local current_content = table.concat(current_lines, "\n")

  return current_content ~= M.original_content
end

--- Show save confirmation dialog
---@param callback function Function to call if user chooses to save
function M.show_save_confirmation(callback)
  local confirm_result = vim.fn.confirm(
    "Do you want to save the note?",
    "&Yes\n&No\n&Cancel",
    1,
    "Question"
  )

  if confirm_result == 1 then -- Yes
    callback()
    M.close_float_window_force()
  elseif confirm_result == 2 then -- No
    M.close_float_window_force()
  end
  -- Cancel (3) or Esc (0) - do nothing
end

--- Close current float window with save confirmation if needed
function M.close_float_window()
  -- Check for unsaved changes in edit modes
  if (M.current_mode == "create" or M.current_mode == "edit" or M.current_mode == "reply") and M.has_unsaved_changes() then
    if M.current_mode == "create" then
      M.show_save_confirmation(function() M.save_note_from_buffer() end)
    elseif M.current_mode == "edit" then
      M.show_save_confirmation(function() M.save_edited_note_from_buffer() end)
    elseif M.current_mode == "reply" then
      M.show_save_confirmation(function() M.save_reply_from_buffer() end)
    end
  else
    M.close_float_window_force()
  end
end

--- Force close current float window without confirmation
function M.close_float_window_force()
  if M.current_win and vim.api.nvim_win_is_valid(M.current_win) then
    vim.api.nvim_win_close(M.current_win, true)
  end
  -- Clear highlights from buffer
  if M.current_buf and vim.api.nvim_buf_is_valid(M.current_buf) and M.highlight_ns then
    vim.api.nvim_buf_clear_namespace(M.current_buf, M.highlight_ns, 0, -1)
  end
  M.current_win = nil
  M.current_buf = nil
  M.original_content = nil
  M.current_mode = nil
  M.current_note = nil
  M.buffer_info = nil
end

--- Create a float window
---@param opts table
---@return number, number -- win_id, buf_id
function M.create_float_window(opts)
  local float_config = config.get_option("ui.float_window")

  -- Calculate window size
  local width = opts.width or float_config.width
  local height = opts.height or float_config.height

  if type(width) == "string" then
    width = math.floor(vim.o.columns * (tonumber(width:sub(1, -2)) / 100))
  end
  if type(height) == "string" then
    height = math.floor(vim.o.lines * (tonumber(height:sub(1, -2)) / 100))
  end

  -- Calculate window position (center)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Create window
  local win_opts = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = float_config.border,
    style = "minimal",
    title = opts.title or "screw.nvim",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "screw")

  -- Set window options
  vim.api.nvim_win_set_option(win, "wrap", true)
  vim.api.nvim_win_set_option(win, "cursorline", true)

  -- Set winblend AFTER window creation
  if float_config.winblend then
    vim.api.nvim_win_set_option(win, "winblend", float_config.winblend)
  end

  return win, buf
end

--- Open create note window
function M.open_create_note_window()
  M.close_float_window()

  -- Store the original buffer info BEFORE opening the floating window
  local buffer_info = utils.get_buffer_info()
  if not buffer_info.filepath or buffer_info.filepath == "" then
    utils.error("Cannot create note: no file open")
    return
  end

  local win, buf = M.create_float_window({
    title = "Create Security Note",
    width = 80,
    height = 23, -- Increased height to accommodate severity field
  })

  M.current_win = win
  M.current_buf = buf
  M.current_mode = "create"
  M.buffer_info = buffer_info  -- Store the original buffer info

  -- Set buffer content
  local lines = {
    "# Create Security Note",
    "",
    "File: " .. buffer_info.relative_path,
    "Line: " .. buffer_info.line_number,
    "Author: " .. utils.get_author(),
    "",
    "## Comment (required)",
    "",
    "",
    "## Description (optional)",
    "",
    "",
    "## CWE (optional, format: CWE-123)",
    "",
    "",
    "## State (vulnerable/not_vulnerable/todo)",
    "",
    "",
    "## Severity (required if state is 'vulnerable', optional otherwise: high/medium/low/info)",
    "",
    "",
    "Press <CR> to save, <Esc> to close",
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply highlights to field titles
  M.apply_field_highlights(buf, M.highlight_ns)

  -- Store original content for change detection
  M.original_content = table.concat(lines, "\n")

  -- Position cursor at comment section
  vim.api.nvim_win_set_cursor(win, { 8, 0 })

  -- Set up keybindings
  local keymap_opts = { buffer = buf, silent = true }

  vim.keymap.set("n", "<CR>", function()
    M.save_note_from_buffer()
    M.close_float_window_force()
  end, keymap_opts)

  vim.keymap.set("n", "<Esc>", function()
    M.close_float_window()
  end, keymap_opts)

  vim.keymap.set("n", "q", function()
    M.close_float_window()
  end, keymap_opts)
end

--- Save note from buffer content
function M.save_note_from_buffer()
  if not M.current_buf or not vim.api.nvim_buf_is_valid(M.current_buf) then
    utils.error("Invalid buffer")
    return
  end

  local lines = vim.api.nvim_buf_get_lines(M.current_buf, 0, -1, false)

  -- Parse content
  local comment = ""
  local description = ""
  local cwe = ""
  local state = ""
  local severity = ""

  local current_section = nil
  for i, line in ipairs(lines) do
    if line:match("^## Comment") then
      current_section = "comment"
    elseif line:match("^## Description") then
      current_section = "description"
    elseif line:match("^## CWE") then
      current_section = "cwe"
    elseif line:match("^## State") then
      current_section = "state"
    elseif line:match("^## Severity") then
      current_section = "severity"
    elseif current_section and line ~= "" and not line:match("^#") and not line:match("^Press") then
      if current_section == "comment" then
        comment = comment .. (comment == "" and "" or "\n") .. line
      elseif current_section == "description" then
        description = description .. (description == "" and "" or "\n") .. line
      elseif current_section == "cwe" then
        cwe = line:gsub("^%s*(.-)%s*$", "%1")
      elseif current_section == "state" then
        state = line:gsub("^%s*(.-)%s*$", "%1")
      elseif current_section == "severity" then
        severity = line:gsub("^%s*(.-)%s*$", "%1")
      end
    end
  end

  -- Validate and create note
  if comment == "" then
    utils.error("Comment is required")
    return
  end

  if state == "" then
    utils.error("State is required (vulnerable/not_vulnerable/todo)")
    return
  end

  -- Validate state
  if not vim.tbl_contains({"vulnerable", "not_vulnerable", "todo"}, state) then
    utils.error("Invalid state. Must be: vulnerable, not_vulnerable, or todo")
    return
  end

  -- Validate severity
  if severity ~= "" and not vim.tbl_contains({"high", "medium", "low", "info"}, severity) then
    utils.error("Invalid severity. Must be: high, medium, low, or info")
    return
  end

  -- Check if severity is required (mandatory for vulnerable state)
  if state == "vulnerable" and severity == "" then
    utils.error("Severity is required when state is 'vulnerable'")
    return
  end

  local opts = {
    comment = comment,
    description = description ~= "" and description or nil,
    cwe = cwe ~= "" and cwe or nil,
    state = state,
    severity = severity ~= "" and severity or nil,
  }

  -- Add error handling around note creation
  local success, result = pcall(function()
    return notes_manager.create_note(opts, M.buffer_info)
  end)

  if not success then
    utils.error("Failed to create note: " .. tostring(result))
    return
  end

  if result then
    utils.info("Note created successfully!")
  end
end

--- Show note selection window for edit/delete operations
---@param notes ScrewNote[]
---@param action string "edit" or "delete"
function M.show_note_selection_window(notes, action)
  if #notes == 0 then
    utils.info("No notes found for current line")
    return
  end

  if #notes == 1 then
    -- Only one note, proceed directly
    if action == "edit" then
      M.open_edit_note_window(notes[1])
    elseif action == "delete" then
      M.delete_note_with_confirmation(notes[1])
    end
    return
  end

  M.close_float_window()

  local win, buf = M.create_float_window({
    title = "Select Note to " .. (action == "edit" and "Edit" or "Delete"),
    width = 100,
    height = math.min(20, #notes * 4 + 5),
  })

  M.current_win = win
  M.current_buf = buf
  M.current_mode = "select"

  -- Generate content
  local lines = {
    "# Select Note to " .. (action == "edit" and "Edit" or "Delete"),
    "",
  }

  for i, note in ipairs(notes) do
    table.insert(lines, string.format("[%d] Note by %s (%s)", i, note.author, note.timestamp))
    table.insert(lines, "    State: " .. note.state .. (note.cwe and " | CWE: " .. note.cwe or ""))
    table.insert(lines, "    Comment: " .. (note.comment:sub(1, 60) .. (#note.comment > 60 and "..." or "")))
    table.insert(lines, "")
  end

  table.insert(lines, "Press number key to select, <Esc> to cancel")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply highlights to field titles
  M.apply_field_highlights(buf, M.highlight_ns)

  -- Set up keybindings
  local keymap_opts = { buffer = buf, silent = true }

  for i = 1, #notes do
    vim.keymap.set("n", tostring(i), function()
      M.close_float_window_force()
      if action == "edit" then
        M.open_edit_note_window(notes[i])
      elseif action == "delete" then
        M.delete_note_with_confirmation(notes[i])
      end
    end, keymap_opts)
  end

  vim.keymap.set("n", "<Esc>", function()
    M.close_float_window_force()
  end, keymap_opts)

  vim.keymap.set("n", "q", function()
    M.close_float_window_force()
  end, keymap_opts)

  -- Make buffer read-only
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

--- Open edit note window
---@param note ScrewNote
function M.open_edit_note_window(note)
  -- Check author permissions
  if note.author ~= utils.get_author() then
    utils.error("You can only edit notes you created (Author: " .. note.author .. ")")
    return
  end

  M.close_float_window()

  local win, buf = M.create_float_window({
    title = "Edit Security Note",
    width = 80,
    height = 23, -- Increased height to accommodate severity field
  })

  M.current_win = win
  M.current_buf = buf
  M.current_mode = "edit"
  M.current_note = note

  -- Set buffer content with existing note data
  local lines = {
    "# Edit Security Note",
    "",
    "File: " .. note.file_path,
    "Line: " .. note.line_number,
    "Author: " .. note.author,
    "Created: " .. note.timestamp,
  }

  if note.updated_at then
    table.insert(lines, "Updated: " .. note.updated_at)
  end

  -- Add remaining content
  local remaining_lines = {
    "",
    "## Comment (required)",
    note.comment,
    "",
    "## Description (optional)",
    note.description or "",
    "",
    "## CWE (optional, format: CWE-123)",
    note.cwe or "",
    "",
    "## State (vulnerable/not_vulnerable/todo)",
    note.state,
    "",
    "## Severity (required if state is 'vulnerable', optional otherwise: high/medium/low/info)",
    note.severity or "",
    "",
    "Press <CR> to save, <Esc> to close",
  }

  for _, line in ipairs(remaining_lines) do
    table.insert(lines, line)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply highlights to field titles
  M.apply_field_highlights(buf, M.highlight_ns)

  -- Store original content for change detection
  M.original_content = table.concat(lines, "\n")

  -- Position cursor at comment section (find the line dynamically)
  local comment_line = 1
  for i, line in ipairs(lines) do
    if line == note.comment and i > 1 and lines[i-1]:match("^## Comment") then
      comment_line = i
      break
    end
  end
  vim.api.nvim_win_set_cursor(win, { comment_line, #note.comment })

  -- Set up keybindings
  local keymap_opts = { buffer = buf, silent = true }

  vim.keymap.set("n", "<CR>", function()
    M.save_edited_note_from_buffer()
    M.close_float_window_force()
  end, keymap_opts)

  vim.keymap.set("n", "<Esc>", function()
    M.close_float_window()
  end, keymap_opts)

  vim.keymap.set("n", "q", function()
    M.close_float_window()
  end, keymap_opts)
end

--- Save edited note from buffer content
function M.save_edited_note_from_buffer()
  if not M.current_buf or not vim.api.nvim_buf_is_valid(M.current_buf) or not M.current_note then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(M.current_buf, 0, -1, false)

  -- Parse content (same logic as create)
  local comment = ""
  local description = ""
  local cwe = ""
  local state = ""

  local current_section = nil
  for i, line in ipairs(lines) do
    if line:match("^## Comment") then
      current_section = "comment"
    elseif line:match("^## Description") then
      current_section = "description"
    elseif line:match("^## CWE") then
      current_section = "cwe"
    elseif line:match("^## State") then
      current_section = "state"
    elseif current_section and line ~= "" and not line:match("^#") and not line:match("^Press") then
      if current_section == "comment" then
        comment = comment .. (comment == "" and "" or "\n") .. line
      elseif current_section == "description" then
        description = description .. (description == "" and "" or "\n") .. line
      elseif current_section == "cwe" then
        cwe = line:gsub("^%s*(.-)%s*$", "%1")
      elseif current_section == "state" then
        state = line:gsub("^%s*(.-)%s*$", "%1")
      end
    end
  end

  -- Validate and update note
  if comment == "" then
    utils.error("Comment is required")
    return
  end

  if state == "" then
    utils.error("State is required (vulnerable/not_vulnerable/todo)")
    return
  end

  local updates = {
    comment = comment,
    description = description ~= "" and description or nil,
    cwe = cwe ~= "" and cwe or nil,
    state = state,
  }

  notes_manager.update_note(M.current_note.id, updates)
end

--- Delete note with confirmation
---@param note ScrewNote
function M.delete_note_with_confirmation(note)
  -- Check author permissions
  if note.author ~= utils.get_author() then
    utils.error("You can only delete notes you created (Author: " .. note.author .. ")")
    return
  end

  local confirm_result = vim.fn.confirm(
    "Delete note by " .. note.author .. "?\n" ..
    "File: " .. note.file_path .. ":" .. note.line_number .. "\n\n" ..
    "Comment: " .. note.comment:sub(1, 100) .. (#note.comment > 100 and "..." or ""),
    "&Yes\n&No",
    2,
    "Question"
  )

  if confirm_result == 1 then -- Yes
    notes_manager.delete_note(note.id)
  end
end

--- Delete all notes in current file with confirmation
function M.delete_current_file_notes_with_confirmation()
  local notes = notes_manager.get_current_file_notes()
  local utils = require("screw.utils")
  local buffer_info = utils.get_buffer_info()

  if #notes == 0 then
    utils.info("No notes found in current file")
    return
  end

  -- Filter notes to only those the user can delete (same author)
  local deletable_notes = {}
  local author = utils.get_author()

  for _, note in ipairs(notes) do
    if note.author == author then
      table.insert(deletable_notes, note)
    end
  end

  if #deletable_notes == 0 then
    utils.info("No notes found in current file that you can delete (you can only delete your own notes)")
    return
  end

  -- Build detailed confirmation message with note previews
  local confirm_lines = {
    "Delete all " .. #deletable_notes .. " note(s) in file?",
    "File: " .. buffer_info.relative_path,
    "",
    "This will delete " .. #deletable_notes .. " of " .. #notes .. " total notes (only your notes will be deleted)",
    "",
    "Notes to be deleted:",
    "──────────────────────────────────────────────────────"
  }

  -- Add details for each note to be deleted
  for i, note in ipairs(deletable_notes) do
    local comment_preview = note.comment:sub(1, 60) .. (#note.comment > 60 and "..." or "")
    -- Escape any characters that might cause highlighting in vim confirm dialogs
    local safe_state = note.state:gsub("[%[%]%(%)%&]", "")
    local safe_comment = comment_preview:gsub("[%[%]%(%)%&]", "")
    table.insert(confirm_lines, string.format("Line %d: %s - %s", note.line_number, safe_state, safe_comment))

    -- Add separator between notes (but not after the last one)
    if i < #deletable_notes then
      table.insert(confirm_lines, "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -")
    end
  end

  table.insert(confirm_lines, "──────────────────────────────────────────────────────")

  local confirm_message = table.concat(confirm_lines, "\n")

  local confirm_result = vim.fn.confirm(
    confirm_message,
    "&Yes\n&No",
    2,
    "Question"
  )

  if confirm_result == 1 then -- Yes
    local deleted_count = 0
    for _, note in ipairs(deletable_notes) do
      if notes_manager.delete_note(note.id) then
        deleted_count = deleted_count + 1
      end
    end

    if deleted_count > 0 then
      utils.info("Successfully deleted " .. deleted_count .. " note(s) from file")
    else
      utils.error("Failed to delete notes")
    end
  end
end

--- Show note selection window for adding replies
---@param notes ScrewNote[]
function M.show_reply_selection_window(notes)
  if #notes == 0 then
    utils.info("No notes found for current line")
    return
  end

  if #notes == 1 then
    -- Only one note, proceed directly
    M.open_reply_window(notes[1])
    return
  end

  M.close_float_window()

  local win, buf = M.create_float_window({
    title = "Select Note to Reply To",
    width = 100,
    height = math.min(20, #notes * 4 + 5),
  })

  M.current_win = win
  M.current_buf = buf
  M.current_mode = "select"

  -- Generate content
  local lines = {
    "# Select Note to Reply To",
    "",
  }

  for i, note in ipairs(notes) do
    table.insert(lines, string.format("[%d] Note by %s (%s)", i, note.author, note.timestamp))
    table.insert(lines, "    State: " .. note.state .. (note.cwe and " | CWE: " .. note.cwe or ""))
    table.insert(lines, "    Comment: " .. (note.comment:sub(1, 60) .. (#note.comment > 60 and "..." or "")))
    table.insert(lines, "")
  end

  table.insert(lines, "Press number key to select, <Esc> to cancel")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply highlights to field titles
  M.apply_field_highlights(buf, M.highlight_ns)

  -- Set up keybindings
  local keymap_opts = { buffer = buf, silent = true }

  for i = 1, #notes do
    vim.keymap.set("n", tostring(i), function()
      M.close_float_window_force()
      M.open_reply_window(notes[i])
    end, keymap_opts)
  end

  vim.keymap.set("n", "<Esc>", function()
    M.close_float_window_force()
  end, keymap_opts)

  vim.keymap.set("n", "q", function()
    M.close_float_window_force()
  end, keymap_opts)

  -- Make buffer read-only
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

--- Open reply window
---@param note ScrewNote
function M.open_reply_window(note)
  M.close_float_window()

  local win, buf = M.create_float_window({
    title = "Reply to Note",
    width = 80,
    height = 20,
  })

  M.current_win = win
  M.current_buf = buf
  M.current_mode = "reply"
  M.current_note = note

  -- Set buffer content
  local lines = {
    "# Reply to Note",
    "",
    "Original Note by: " .. note.author,
    "## Comment",
    note.comment:sub(1, 80) .. (#note.comment > 80 and "..." or ""),
    "",
    "## State",
    note.state,
  }

  if note.cwe then
    table.insert(lines, "")
    table.insert(lines, "## CWE")
    table.insert(lines, note.cwe)
  end

  -- Add reply section
  local reply_lines = {
    "",
    "## Your Reply",
    "",
    "",
    "",
    "Press <CR> to save, <Esc> to close",
  }

  for _, line in ipairs(reply_lines) do
    table.insert(lines, line)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply highlights to field titles
  M.apply_field_highlights(buf, M.highlight_ns)

  -- Store original content for change detection
  M.original_content = table.concat(lines, "\n")

  -- Position cursor at reply section (find the line dynamically)
  local reply_line = 1
  for i, line in ipairs(lines) do
    if line == "## Your Reply" then
      reply_line = i + 1  -- Position cursor on the line after "## Your Reply"
      break
    end
  end
  vim.api.nvim_win_set_cursor(win, { reply_line, 0 })

  -- Set up keybindings
  local keymap_opts = { buffer = buf, silent = true }

  vim.keymap.set("n", "<CR>", function()
    M.save_reply_from_buffer()
    M.close_float_window_force()
  end, keymap_opts)

  vim.keymap.set("n", "<Esc>", function()
    M.close_float_window()
  end, keymap_opts)

  vim.keymap.set("n", "q", function()
    M.close_float_window()
  end, keymap_opts)
end

--- Save reply from buffer content
function M.save_reply_from_buffer()
  if not M.current_buf or not vim.api.nvim_buf_is_valid(M.current_buf) or not M.current_note then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(M.current_buf, 0, -1, false)

  -- Parse reply content
  local reply_comment = ""
  local in_reply_section = false

  for i, line in ipairs(lines) do
    if line:match("^## Your Reply") then
      in_reply_section = true
    elseif in_reply_section and line ~= "" and not line:match("^Press") then
      reply_comment = reply_comment .. (reply_comment == "" and "" or "\n") .. line
    end
  end

  -- Validate and save reply
  if reply_comment == "" then
    utils.error("Reply comment cannot be empty")
    return
  end

  notes_manager.add_reply(M.current_note.id, reply_comment, utils.get_author())
end

--- Open view notes window for current line
function M.open_view_notes_window()
  local notes = notes_manager.get_current_line_notes()
  if #notes == 0 then
    utils.info("No notes found for current line")
    return
  end

  M.show_notes_window(notes, "Notes for Current Line")
end

--- Open view notes window for current file
function M.open_file_notes_window()
  local notes = notes_manager.get_current_file_notes()
  if #notes == 0 then
    utils.info("No notes found for current file")
    return
  end

  M.show_notes_window(notes, "Notes for Current File")
end

--- Open view notes window for all notes
function M.open_all_notes_window()
  local notes = notes_manager.get_notes()
  if #notes == 0 then
    utils.info("No notes found")
    return
  end

  M.show_notes_window(notes, "All Notes")
end

--- Show notes in a window
---@param notes ScrewNote[]
---@param title string
function M.show_notes_window(notes, title)
  M.close_float_window()

  local win, buf = M.create_float_window({
    title = title,
    width = 100,
    height = 30,
  })

  M.current_win = win
  M.current_buf = buf
  M.current_mode = "view"

  -- Generate content with BBS-style thread display
  local lines = {}

  for i, note in ipairs(notes) do
    table.insert(lines, "# Note " .. i .. " - " .. note.id)
    table.insert(lines, "")
    table.insert(lines, "File: " .. note.file_path .. ":" .. note.line_number)
    table.insert(lines, "Author: " .. note.author)
    table.insert(lines, "Created: " .. note.timestamp)
    if note.updated_at then
      table.insert(lines, "Updated: " .. note.updated_at)
    end
    table.insert(lines, "State: " .. note.state)

    if note.cwe then
      table.insert(lines, "CWE: " .. note.cwe)
    end

    table.insert(lines, "")
    table.insert(lines, "## Comment")
    table.insert(lines, note.comment)

    if note.description then
      table.insert(lines, "")
      table.insert(lines, "## Description")
      table.insert(lines, note.description)
    end

    -- BBS-style thread display for replies
    if note.replies and #note.replies > 0 then
      table.insert(lines, "")
      table.insert(lines, "## Thread (" .. #note.replies .. " replies)")
      table.insert(lines, "")

      -- Sort replies by timestamp
      local sorted_replies = vim.deepcopy(note.replies)
      table.sort(sorted_replies, function(a, b)
        return a.timestamp < b.timestamp
      end)

      for j, reply in ipairs(sorted_replies) do
        -- Add separator line (BBS style)
        table.insert(lines, "────────────────────────────────────────────────────────────────────────────────")
        table.insert(lines, "From: " .. reply.author .. " | Date: " .. reply.timestamp)
        table.insert(lines, "")
        table.insert(lines, reply.comment)
        table.insert(lines, "")
      end

      table.insert(lines, "────────────────────────────────────────────────────────────────────────────────")
      table.insert(lines, "End of thread")
    end

    if i < #notes then
      table.insert(lines, "")
      table.insert(lines, "═══════════════════════════════════════════════════════════════════════════════")
      table.insert(lines, "")
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Press <Esc> or 'q' to close")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Apply highlights to field titles
  M.apply_field_highlights(buf, M.highlight_ns)

  -- Set up keybindings
  local keymap_opts = { buffer = buf, silent = true }

  vim.keymap.set("n", "<Esc>", function()
    M.close_float_window_force()
  end, keymap_opts)

  vim.keymap.set("n", "q", function()
    M.close_float_window_force()
  end, keymap_opts)

  -- Make buffer read-only
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

--- Public API functions for external use

--- Open edit note window for current line
function M.open_edit_current_line_notes()
  local notes = notes_manager.get_current_line_notes()
  M.show_note_selection_window(notes, "edit")
end

--- Open delete note window for current line
function M.open_delete_current_line_notes()
  local notes = notes_manager.get_current_line_notes()
  M.show_note_selection_window(notes, "delete")
end

--- Open reply window for current line
function M.open_reply_current_line_notes()
  local notes = notes_manager.get_current_line_notes()
  M.show_reply_selection_window(notes)
end

return M