--- Telescope extension for screw.nvim
---
--- This extension provides telescope integration for searching through security notes.
---

local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("This extension requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local tel_utils = require("telescope.utils")
local entry_display = require("telescope.pickers.entry_display")

local screw = require("screw")
local screw_utils = require("screw.utils")

local M = {}

--- Format a note for display in telescope
---@param note ScrewNote
---@return table
local function format_note_entry(note)
  -- Convert relative path to absolute path for file operations
  local absolute_path = screw_utils.get_absolute_path(note.file_path)

  local display_items = {
    { note.file_path, "TelescopeResultsIdentifier" },
    { ":" .. note.line_number, "TelescopeResultsLineNr" },
    { "[" .. note.state .. "]", note.state == "vulnerable" and "DiagnosticError" or
      note.state == "not_vulnerable" and "DiagnosticOk" or "DiagnosticWarn" },
  }

  if note.severity then
    table.insert(display_items, { "[" .. note.severity .. "]",
      note.severity == "high" and "DiagnosticError" or
      note.severity == "medium" and "DiagnosticWarn" or
      note.severity == "low" and "DiagnosticInfo" or "DiagnosticHint" })
  end

  if note.cwe then
    table.insert(display_items, { "[" .. note.cwe .. "]", "DiagnosticInfo" })
  end

  table.insert(display_items, { note.comment, "TelescopeResultsComment" })

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 30 },  -- file_path
      { width = 6 },   -- line_number
      { width = 15 },  -- state
      { width = 10 },  -- severity
      { width = 10 },  -- cwe
      { remaining = true }, -- comment
    },
  })

  return {
    value = note,
    display = function(entry)
      return displayer(display_items)
    end,
    ordinal = table.concat({
      note.file_path,
      ":" .. note.line_number,
      note.comment,
      note.description or "",
      note.state,
      note.cwe or "",
      note.severity or "",
      note.author,
    }, " "),
    filename = absolute_path,  -- Use absolute path for file operations
    lnum = note.line_number,
    col = 1,
    text = note.comment .. (note.description and ("\n" .. note.description) or ""),
    path = absolute_path,  -- Use absolute path for preview
  }
end

--- Filter notes based on options
---@param notes ScrewNote[]
---@param opts table
---@return ScrewNote[]
local function filter_notes(notes, opts)
  if not opts.filter then
    return notes
  end

  local filtered = {}
  for _, note in ipairs(notes) do
    local matches = true

    -- Filter by state
    if opts.filter.state and note.state ~= opts.filter.state then
      matches = false
    end

    -- Filter by severity
    if opts.filter.severity and note.severity ~= opts.filter.severity then
      matches = false
    end

    -- Filter by CWE
    if opts.filter.cwe and note.cwe ~= opts.filter.cwe then
      matches = false
    end

    -- Filter by author
    if opts.filter.author and note.author ~= opts.filter.author then
      matches = false
    end

    -- Filter by keywords (search in comment and description)
    if opts.filter.keywords then
      local search_text = (note.comment .. " " .. (note.description or "")):lower()
      local keywords_match = false
      for _, keyword in ipairs(opts.filter.keywords) do
        if search_text:find(keyword:lower(), 1, true) then
          keywords_match = true
          break
        end
      end
      if not keywords_match then
        matches = false
      end
    end

    -- Filter by file (for current file scope)
    if opts.scope == "file" then
      local current_file = vim.fn.expand("%:.")
      if note.file_path ~= current_file then
        matches = false
      end
    end

    if matches then
      table.insert(filtered, note)
    end
  end

  return filtered
end

--- Main telescope picker for security notes
---@param opts table?
function M.notes(opts)
  opts = opts or {}

  -- Get all notes
  local all_notes = screw.get_notes()

  -- Filter notes based on options
  local notes = filter_notes(all_notes, opts)

  if #notes == 0 then
    tel_utils.notify("screw.notes", {
      msg = "No security notes found",
      level = "INFO",
    })
    return
  end

  -- Sort notes by file path then line number
  table.sort(notes, function(a, b)
    if a.file_path == b.file_path then
      return a.line_number < b.line_number
    end
    return a.file_path < b.file_path
  end)

  pickers.new(opts, {
    prompt_title = "Security Notes",
    finder = finders.new_table({
      results = notes,
      entry_maker = format_note_entry,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          -- Jump to the note location
          vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))

          -- Validate line number and set cursor position safely
          local line_count = vim.api.nvim_buf_line_count(0)
          local target_line = math.min(selection.lnum, line_count)
          target_line = math.max(target_line, 1)

          vim.api.nvim_win_set_cursor(0, { target_line, 0 })

          -- Show note details
          screw.view_current_line_notes()
        end
      end)

      -- Add custom mapping for editing note
      map("i", "<C-e>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          actions.close(prompt_bufnr)
          vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))

          -- Validate line number and set cursor position safely
          local line_count = vim.api.nvim_buf_line_count(0)
          local target_line = math.min(selection.lnum, line_count)
          target_line = math.max(target_line, 1)

          vim.api.nvim_win_set_cursor(0, { target_line, 0 })
          screw.edit_note()
        end
      end)

      -- Add custom mapping for deleting note
      map("i", "<C-d>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          actions.close(prompt_bufnr)
          vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))

          -- Validate line number and set cursor position safely
          local line_count = vim.api.nvim_buf_line_count(0)
          local target_line = math.min(selection.lnum, line_count)
          target_line = math.max(target_line, 1)

          vim.api.nvim_win_set_cursor(0, { target_line, 0 })
          screw.delete_note()
        end
      end)

      return true
    end,
  }):find()
end

--- Search notes in current file only
---@param opts table?
function M.file_notes(opts)
  opts = opts or {}
  opts.scope = "file"
  M.notes(opts)
end

--- Search vulnerable notes only
---@param opts table?
function M.vulnerable_notes(opts)
  opts = opts or {}
  opts.filter = opts.filter or {}
  opts.filter.state = "vulnerable"
  M.notes(opts)
end

--- Search todo notes only
---@param opts table?
function M.todo_notes(opts)
  opts = opts or {}
  opts.filter = opts.filter or {}
  opts.filter.state = "todo"
  M.notes(opts)
end

--- Search notes by CWE
---@param opts table?
function M.cwe_notes(opts)
  opts = opts or {}
  if not opts.filter or not opts.filter.cwe then
    local cwe = vim.fn.input("Enter CWE ID (e.g., CWE-79): ")
    if cwe == "" then
      return
    end
    opts.filter = opts.filter or {}
    opts.filter.cwe = cwe
  end
  M.notes(opts)
end

return telescope.register_extension({
  setup = function(ext_config, config)
    -- Extension setup if needed
  end,
  exports = {
    screw = M.notes,
    notes = M.notes,
    file_notes = M.file_notes,
    vulnerable = M.vulnerable_notes,
    todo = M.todo_notes,
    cwe = M.cwe_notes,
  },
})