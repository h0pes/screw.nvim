--- User commands for screw.nvim
---
--- This file sets up user commands following Neovim plugin best practices.
--- All commands are scoped under the :Screw command with subcommands.

-- Only load commands if Neovim version is supported
if vim.fn.has("nvim-0.9.0") == 0 then
  vim.api.nvim_err_writeln("screw.nvim requires Neovim >= 0.9.0")
  return
end

local function screw_command(opts)
  local subcommand = opts.fargs[1]
  local args = vim.list_slice(opts.fargs, 2)
  
  if subcommand == "note" then
    local screw = require("screw")
    local action = args[1]
    local note_args = vim.list_slice(args, 2)
    
    if action == "add" then
      screw.create_note()
    elseif action == "edit" then
      screw.edit_note()
    elseif action == "delete" then
      local scope = note_args[1] or "line"
      if scope == "line" then
        screw.delete_note()
      elseif scope == "file" then
        screw.delete_current_file_notes()
      elseif scope == "project" then
        screw.delete_all_project_notes()
      else
        vim.api.nvim_err_writeln("Invalid delete scope: " .. scope .. ". Use: line, file, or project")
      end
    elseif action == "reply" then
      screw.reply_to_note()
    elseif action == "view" then
      local scope = note_args[1] or "line"
      if scope == "line" then
        screw.view_current_line_notes()
      elseif scope == "file" then
        screw.view_current_file_notes()
      elseif scope == "project" then
        screw.view_all_notes()
      else
        vim.api.nvim_err_writeln("Invalid scope: " .. scope .. ". Use: line, file, or project")
      end
    else
      vim.api.nvim_err_writeln("Unknown note action: " .. (action or ""))
      vim.api.nvim_err_writeln("Available note actions: add, edit, delete [line|file|project], reply, view [line|file|project]")
    end
  elseif subcommand == "export" then
    local screw = require("screw")
    local format = args[1] or "markdown"
    local output_path = args[2]
    
    local options = {
      format = format,
      output_path = output_path,
    }
    
    screw.export_notes(options)
  elseif subcommand == "import" then
    local format = args[1]
    local input_path = args[2]
    
    if not format or not input_path then
      vim.api.nvim_err_writeln("Usage: :Screw import <format> <input_path>")
      vim.api.nvim_err_writeln("Supported formats: sarif")
      return
    end
    
    if format ~= "sarif" then
      vim.api.nvim_err_writeln("Unsupported import format: " .. format)
      vim.api.nvim_err_writeln("Currently supported: sarif")
      return
    end
    
    local screw = require("screw")
    local options = {
      format = format,
      input_path = input_path,
    }
    
    screw.import_notes(options)
  elseif subcommand == "stats" then
    local screw = require("screw")
    local stats = screw.get_statistics()
    local lines = {
      "# screw.nvim Statistics",
      "",
      "Total notes: " .. stats.total,
      "Vulnerable: " .. stats.vulnerable,
      "Not vulnerable: " .. stats.not_vulnerable,
      "Todo: " .. stats.todo,
      "",
      "## By Severity",
      "High: " .. stats.by_severity.high,
      "Medium: " .. stats.by_severity.medium,
      "Low: " .. stats.by_severity.low,
      "Info: " .. stats.by_severity.info,
      "",
      "Files with notes: " .. #stats.files_with_notes,
    }
    
    -- Show in a simple buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    vim.api.nvim_buf_set_option(buf, "readonly", true)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_win_set_buf(0, buf)
  elseif subcommand == "jump" then
    local screw = require("screw")
    local direction = args[1]
    local keywords = vim.list_slice(args, 2)
    
    if direction == "next" then
      local opts = #keywords > 0 and { keywords = keywords } or {}
      screw.jump_next(opts)
    elseif direction == "prev" then
      local opts = #keywords > 0 and { keywords = keywords } or {}
      screw.jump_prev(opts)
    else
      vim.api.nvim_err_writeln("Invalid jump direction: " .. (direction or "") .. ". Use: next or prev")
    end
  elseif subcommand == "search" then
    -- Check if telescope is available
    local has_telescope, telescope = pcall(require, "telescope")
    if not has_telescope then
      vim.api.nvim_err_writeln("Telescope is required for search functionality. Install nvim-telescope/telescope.nvim")
      return
    end
    
    -- Parse search options
    local scope = "project"  -- default scope
    local filter = {}
    local i = 1
    
    while i <= #args do
      local arg = args[i]
      if arg == "--file" or arg == "-f" then
        scope = "file"
      elseif arg == "--project" or arg == "-p" then
        scope = "project"
      elseif arg == "--state" or arg == "-s" then
        i = i + 1
        if i <= #args then
          filter.state = args[i]
        end
      elseif arg == "--severity" then
        i = i + 1
        if i <= #args then
          filter.severity = args[i]
        end
      elseif arg == "--cwe" then
        i = i + 1
        if i <= #args then
          filter.cwe = args[i]
        end
      elseif arg == "--author" then
        i = i + 1
        if i <= #args then
          filter.author = args[i]
        end
      elseif arg == "--keywords" or arg == "-k" then
        filter.keywords = {}
        i = i + 1
        while i <= #args and not args[i]:match("^%-") do
          table.insert(filter.keywords, args[i])
          i = i + 1
        end
        i = i - 1  -- Adjust for the loop increment
      end
      i = i + 1
    end
    
    -- Call appropriate telescope function
    if scope == "file" then
      telescope.extensions.screw.file_notes({ filter = filter })
    else
      telescope.extensions.screw.notes({ filter = filter })
    end
  else
    vim.api.nvim_err_writeln("Unknown subcommand: " .. (subcommand or ""))
    vim.api.nvim_err_writeln("Available subcommands: note, export, import, stats, jump, search")
  end
end

local function screw_complete(arg_lead, cmd_line, cursor_pos)
  local args = vim.split(cmd_line, "%s+")
  local num_args = #args
  
  -- Remove the command name
  if args[1] == "Screw" then
    num_args = num_args - 1
    args = vim.list_slice(args, 2)
  end
  
  if num_args <= 1 then
    -- Complete subcommands
    local subcommands = { "note", "export", "import", "stats", "jump", "search" }
    local matches = {}
    
    for _, cmd in ipairs(subcommands) do
      if cmd:sub(1, #arg_lead) == arg_lead then
        table.insert(matches, cmd)
      end
    end
    
    return matches
  elseif num_args >= 2 then
    local subcommand = args[1]
    
    if subcommand == "note" then
      if num_args == 2 then
        -- Complete note actions
        local actions = { "add", "edit", "delete", "reply", "view" }
        local matches = {}
        
        for _, action in ipairs(actions) do
          if action:sub(1, #arg_lead) == arg_lead then
            table.insert(matches, action)
          end
        end
        
        return matches
      elseif num_args == 3 and args[2] == "view" then
        -- Complete view scopes
        local scopes = { "line", "file", "project" }
        local matches = {}
        
        for _, scope in ipairs(scopes) do
          if scope:sub(1, #arg_lead) == arg_lead then
            table.insert(matches, scope)
          end
        end
        
        return matches
      elseif num_args == 3 and args[2] == "delete" then
        -- Complete delete scopes
        local scopes = { "line", "file", "project" }
        local matches = {}
        
        for _, scope in ipairs(scopes) do
          if scope:sub(1, #arg_lead) == arg_lead then
            table.insert(matches, scope)
          end
        end
        
        return matches
      end
    elseif subcommand == "export" then
      if num_args == 2 then
        local formats = { "markdown", "json", "csv", "sarif" }
        local matches = {}
        
        for _, format in ipairs(formats) do
          if format:sub(1, #arg_lead) == arg_lead then
            table.insert(matches, format)
          end
        end
        
        return matches
      elseif num_args == 3 then
        -- Complete file paths for output
        return vim.fn.glob(arg_lead .. "*", false, true)
      end
    elseif subcommand == "import" then
      if num_args == 2 then
        local formats = { "sarif" }
        local matches = {}
        
        for _, format in ipairs(formats) do
          if format:sub(1, #arg_lead) == arg_lead then
            table.insert(matches, format)
          end
        end
        
        return matches
      elseif num_args == 3 then
        -- Complete file paths for input
        return vim.fn.glob(arg_lead .. "*", false, true)
      end
    elseif subcommand == "jump" then
      if num_args == 2 then
        local directions = { "next", "prev" }
        local matches = {}
        
        for _, direction in ipairs(directions) do
          if direction:sub(1, #arg_lead) == arg_lead then
            table.insert(matches, direction)
          end
        end
        
        return matches
      elseif num_args >= 3 then
        -- Complete keywords - return common security terms without initializing plugin
        local common_keywords = { "auth", "crypto", "sql", "xss", "csrf", "injection", "validation", "sanitize" }
        local matches = {}
        
        for _, keyword in ipairs(common_keywords) do
          if keyword:upper():sub(1, #arg_lead:upper()) == arg_lead:upper() then
            table.insert(matches, keyword)
          end
        end
        
        return matches
      end
    elseif subcommand == "search" then
      -- Complete search options
      local options = { "--file", "-f", "--project", "-p", "--state", "-s", "--severity", "--cwe", "--author", "--keywords", "-k" }
      local matches = {}
      
      for _, option in ipairs(options) do
        if option:sub(1, #arg_lead) == arg_lead then
          table.insert(matches, option)
        end
      end
      
      return matches
    end
  end
  
  return {}
end

-- Create the main command
vim.api.nvim_create_user_command("Screw", screw_command, {
  nargs = "*",
  complete = screw_complete,
  desc = "Security code review notes",
})

-- Create plug mappings for all major actions (users can map these to their preferred keys)
-- Note: These use lazy loading - screw module is only required when the mapping is actually used
vim.keymap.set("n", "<Plug>(ScrewCreateNote)", function()
  require("screw").create_note()
end, { desc = "Create a security note" })

vim.keymap.set("n", "<Plug>(ScrewEditNote)", function()
  require("screw").edit_note()
end, { desc = "Edit a security note" })

vim.keymap.set("n", "<Plug>(ScrewDeleteNote)", function()
  require("screw").delete_note()
end, { desc = "Delete a security note" })

vim.keymap.set("n", "<Plug>(ScrewReplyToNote)", function()
  require("screw").reply_to_note()
end, { desc = "Reply to a security note" })

vim.keymap.set("n", "<Plug>(ScrewViewLineNotes)", function()
  require("screw").view_current_line_notes()
end, { desc = "View notes for current line" })

vim.keymap.set("n", "<Plug>(ScrewViewFileNotes)", function()
  require("screw").view_current_file_notes()
end, { desc = "View notes for current file" })

vim.keymap.set("n", "<Plug>(ScrewViewAllNotes)", function()
  require("screw").view_all_notes()
end, { desc = "View all notes in project" })

vim.keymap.set("n", "<Plug>(ScrewExportMarkdown)", function()
  require("screw").export_notes({ format = "markdown" })
end, { desc = "Export notes to Markdown" })

vim.keymap.set("n", "<Plug>(ScrewStats)", function()
  require("screw").get_statistics()
end, { desc = "Show security review statistics" })

vim.keymap.set("n", "<Plug>(ScrewJumpNext)", function()
  require("screw").jump_next()
end, { desc = "Jump to next security note" })

vim.keymap.set("n", "<Plug>(ScrewJumpPrev)", function()
  require("screw").jump_prev()
end, { desc = "Jump to previous security note" })
