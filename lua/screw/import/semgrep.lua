--- Semgrep importer for screw.nvim
---
--- This module parses Semgrep JSON output and converts it to screw notes.
---

local utils = require("screw.utils")

local M = {}

--- Parse Semgrep JSON output
---@param content string
---@param options ScrewImportOptions
---@return table[]
function M.parse(content, options)
  -- Parse JSON
  local success, data = pcall(vim.json.decode, content)
  if not success then
    utils.error("Failed to parse Semgrep JSON: " .. data)
    return {}
  end

  local notes = {}

  -- Handle Semgrep output format
  local results = data.results or {}

  for _, result in ipairs(results) do
    local note = M.convert_result_to_note(result, options)
    if note then
      table.insert(notes, note)
    end
  end

  return notes
end

--- Convert Semgrep result to screw note
---@param result table
---@param options ScrewImportOptions
---@return table?
function M.convert_result_to_note(result, options)
  if not result.path or not result.start or not result.start.line then
    return nil
  end

  -- Extract basic information
  local file_path = result.path
  local line_number = result.start.line
  local rule_id = result.check_id or "unknown"
  local message = result.message or "Semgrep finding"

  -- Build comment
  local comment = string.format("[%s] %s", rule_id, message)

  -- Build description with additional details
  local description_parts = {}

  if result.extra and result.extra.message then
    table.insert(description_parts, "Details: " .. result.extra.message)
  end

  if result.extra and result.extra.metavars then
    table.insert(description_parts, "Variables: " .. vim.inspect(result.extra.metavars))
  end

  if result.fix then
    table.insert(description_parts, "Suggested fix: " .. result.fix)
  end

  local description = #description_parts > 0 and table.concat(description_parts, "\n\n") or nil

  -- Map severity to CWE if available
  local cwe = nil
  if result.extra and result.extra.metadata then
    local metadata = result.extra.metadata
    if metadata.cwe then
      cwe = type(metadata.cwe) == "table" and metadata.cwe[1] or metadata.cwe
      if cwe and not cwe:match("^CWE%-") then
        cwe = "CWE-" .. cwe
      end
    end
  end

  -- Map Semgrep severity to our severity levels and determine state
  local severity = nil
  local state = "todo"

  if result.extra and result.extra.severity then
    local semgrep_severity = result.extra.severity:lower()

    -- Map Semgrep severities to our standard levels
    if semgrep_severity == "error" then
      severity = "high"
      state = "vulnerable"
    elseif semgrep_severity == "warning" then
      severity = "medium"
      state = "vulnerable"
    elseif semgrep_severity == "info" then
      severity = "info"
      state = "not_vulnerable"
    else
      -- For unknown severities, try direct mapping
      if vim.tbl_contains({ "high", "medium", "low", "info" }, semgrep_severity) then
        severity = semgrep_severity
        if semgrep_severity == "high" or semgrep_severity == "medium" then
          state = "vulnerable"
        else
          state = "not_vulnerable"
        end
      end
    end
  end

  return {
    file_path = utils.get_relative_path(file_path), -- Convert absolute to relative for notes
    line_number = line_number,
    comment = comment,
    description = description,
    cwe = cwe,
    state = state,
    severity = severity,
  }
end

return M
