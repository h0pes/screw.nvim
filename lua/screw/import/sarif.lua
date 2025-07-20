--- SARIF import functionality for screw.nvim
---
--- This module handles importing security findings from SARIF v2.1.0 files
--- and converting them to screw.nvim note format.
---
--- SARIF spec: https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html
---

local utils = require("screw.utils")

local M = {}

--- Extract CWE from SARIF rule tags
---@param rule table SARIF rule object
---@return string? CWE identifier or nil
local function extract_cwe_from_rule(rule)
  if not rule.properties or not rule.properties.tags then
    return nil
  end

  for _, tag in ipairs(rule.properties.tags) do
    if type(tag) == "string" then
      local cwe_match = tag:match("external/cwe/cwe%-(%d+)")
      if cwe_match then
        return "CWE-" .. cwe_match
      end
    end
  end

  return nil
end

--- Map SARIF level and severity to screw.nvim state and severity
---@param sarif_level string SARIF level ("error", "warning", "note", "none")
---@param sarif_severity string? Tool-specific severity
---@return string state screw.nvim state
---@return string? severity screw.nvim severity
local function map_sarif_to_screw_state(sarif_level, sarif_severity)
  -- SARIF level mapping to screw state
  if sarif_level == "error" then
    local severity = "high" -- Default for errors
    if sarif_severity then
      local sev_lower = sarif_severity:lower()
      if sev_lower == "high" or sev_lower == "critical" then
        severity = "high"
      elseif sev_lower == "medium" then
        severity = "medium"
      elseif sev_lower == "low" then
        severity = "low"
      end
    end
    return "vulnerable", severity
  elseif sarif_level == "warning" then
    local severity = "medium" -- Default for warnings
    if sarif_severity then
      local sev_lower = sarif_severity:lower()
      if sev_lower == "high" or sev_lower == "critical" then
        severity = "high"
      elseif sev_lower == "medium" then
        severity = "medium"
      elseif sev_lower == "low" then
        severity = "low"
      end
    end
    return "todo", severity
  elseif sarif_level == "note" then
    return "todo", "info"
  else -- "none" or other
    return "todo", "info"
  end
end

--- Convert SARIF file URI to relative path
---@param sarif_uri string SARIF artifact location URI
---@param project_root string Project root directory
---@return string? relative_path Relative path or nil if file not in project
local function resolve_file_path(sarif_uri, project_root)
  -- Remove file:// protocol if present
  local absolute_path = sarif_uri:gsub("^file://", "")

  -- Convert to relative path from project root
  local relative_path = vim.fn.fnamemodify(absolute_path, ":~:.")

  -- If path starts with ../ it's outside project, skip it
  if relative_path:match("^%.%./") then
    return nil
  end

  -- Validate file exists
  if vim.fn.filereadable(absolute_path) == 0 then
    -- Try relative path from current directory
    if vim.fn.filereadable(relative_path) == 1 then
      return relative_path
    end
    return nil
  end

  return relative_path
end

--- Generate unique ID for imported note based on SARIF content
---@param sarif_result table SARIF result object
---@param rule_id string Rule ID from SARIF
---@return string
local function generate_note_id(sarif_result, rule_id)
  -- Create deterministic ID based on SARIF content to prevent duplicates
  local location = sarif_result.locations[1]
  local file_uri = location.physicalLocation.artifactLocation.uri
  local line_number = location.physicalLocation.region.startLine or 1

  -- Extract filename from URI for shorter ID
  local filename = file_uri:match("([^/]+)$") or "unknown"

  -- Create deterministic ID: sarif-<rule>-<file>-<line>-<hash>
  local content_hash = tostring(sarif_result.message.text:len() + line_number)
  return string.format("sarif-%s-%s-%d-%s", rule_id or "unknown", filename, line_number, content_hash)
end

--- Convert SARIF result to screw.nvim note
---@param result table SARIF result object
---@param rules table[] SARIF rules array
---@param tool_info table SARIF tool driver info
---@param import_metadata table Import metadata
---@return ScrewNote? note Converted note or nil if conversion failed
local function convert_sarif_result_to_note(result, rules, tool_info, import_metadata)
  -- Validate required fields
  if not result.locations or #result.locations == 0 then
    return nil
  end

  local location = result.locations[1]
  if
    not location.physicalLocation
    or not location.physicalLocation.artifactLocation
    or not location.physicalLocation.region
  then
    return nil
  end

  local artifact = location.physicalLocation.artifactLocation
  local region = location.physicalLocation.region

  -- Resolve file path
  local file_path = resolve_file_path(artifact.uri, vim.fn.getcwd())
  if not file_path then
    return nil -- Skip files outside project
  end

  -- Find rule information
  local rule = nil
  if result.ruleId and rules then
    for _, r in ipairs(rules) do
      if r.id == result.ruleId then
        rule = r
        break
      end
    end
  end

  -- Extract CWE
  local cwe = nil
  if rule then
    cwe = extract_cwe_from_rule(rule)
  end

  -- Map state and severity
  local state, severity =
    map_sarif_to_screw_state(result.level or "note", result.properties and result.properties.issue_severity)

  -- Build comment from message
  local comment = result.message and result.message.text or "Imported security finding"

  -- Build description from code snippet if available
  local description = nil
  if region.snippet and region.snippet.text then
    description = region.snippet.text:gsub("\n$", "") -- Remove trailing newline
  end

  -- Create note
  local note = {
    id = generate_note_id(result, result.ruleId),
    file_path = file_path,
    line_number = region.startLine or 1,
    author = import_metadata.author or "sarif-import",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    comment = comment,
    description = description,
    cwe = cwe,
    state = state,
    severity = severity,
    source = "sarif-import",
    import_metadata = {
      tool_name = tool_info.name or "Unknown",
      sarif_file_path = import_metadata.sarif_file_path,
      import_timestamp = import_metadata.import_timestamp,
      rule_id = result.ruleId or "unknown",
      confidence = result.properties and result.properties.issue_confidence,
      original_severity = result.properties and result.properties.issue_severity,
      original_level = result.level,
    },
  }

  return note
end

--- Detect collision between new note and existing notes
---@param new_note ScrewNote
---@param existing_notes ScrewNote[]
---@return string collision_type "none"|"duplicate"|"collision"|"native_vs_import"|"import_vs_native"
---@return ScrewNote? existing_note The colliding note if any
local function detect_collision(new_note, existing_notes)
  for _, existing in ipairs(existing_notes) do
    if existing.file_path == new_note.file_path and existing.line_number == new_note.line_number then
      -- Check source types
      if existing.source == "sarif-import" and new_note.source == "sarif-import" then
        -- Both imported - check if same rule
        if
          existing.import_metadata
          and new_note.import_metadata
          and existing.import_metadata.rule_id == new_note.import_metadata.rule_id
        then
          return "duplicate", existing
        else
          return "collision", existing
        end
      elseif existing.source == "native" and new_note.source == "sarif-import" then
        return "native_vs_import", existing
      elseif (existing.source == "sarif-import" or not existing.source) and new_note.source == "sarif-import" then
        return "import_vs_native", existing
      else
        return "collision", existing
      end
    end
  end
  return "none", nil
end

--- Handle collision based on strategy
---@param collision_type string
---@param new_note ScrewNote
---@param existing_note ScrewNote
---@param strategy string
---@return boolean should_import Whether to import the new note
local function handle_collision(collision_type, new_note, existing_note, strategy)
  if collision_type == "duplicate" then
    return false -- Never import duplicates
  end

  if strategy == "skip" then
    return false
  elseif strategy == "overwrite" then
    -- Delete existing note first
    local notes_manager = require("screw.notes.manager")
    notes_manager.delete_note(existing_note.id)
    return true
  elseif strategy == "ask" then
    -- Show collision dialog and get user choice
    local choice = vim.fn.confirm(
      string.format(
        "Collision detected at %s:%d\n\nExisting: %s\nNew: %s\n\nWhat would you like to do?",
        new_note.file_path,
        new_note.line_number,
        existing_note.comment:sub(1, 50) .. (existing_note.comment:len() > 50 and "..." or ""),
        new_note.comment:sub(1, 50) .. (new_note.comment:len() > 50 and "..." or "")
      ),
      "&Skip\n&Overwrite\n&Keep both",
      1
    )

    if choice == 2 then -- Overwrite
      local notes_manager = require("screw.notes.manager")
      notes_manager.delete_note(existing_note.id)
      return true
    elseif choice == 3 then -- Keep both
      return true
    else -- Skip
      return false
    end
  end

  return false
end

--- Parse and validate SARIF JSON
---@param content string SARIF file content
---@return table? sarif_data Parsed SARIF data or nil if invalid
---@return string? error_message Error message if parsing failed
function M.parse_sarif(content)
  -- Parse JSON
  local success, sarif_data = pcall(vim.json.decode, content)
  if not success then
    return nil, "Invalid JSON: " .. tostring(sarif_data)
  end

  -- Basic SARIF validation
  if not sarif_data.version then
    return nil, "Missing SARIF version"
  end

  if not sarif_data.runs or #sarif_data.runs == 0 then
    return nil, "No runs found in SARIF file"
  end

  -- Check version compatibility (accept 2.1.0 and similar)
  if not sarif_data.version:match("^2%.1%.") then
    utils.warn("SARIF version " .. sarif_data.version .. " may not be fully compatible. Expected 2.1.x")
  end

  return sarif_data, nil
end

--- Import SARIF file
---@param file_path string Path to SARIF file
---@param options ScrewImportOptions Import options
---@return ScrewImportResult Import result
function M.import(file_path, options)
  local result = {
    success = false,
    total_findings = 0,
    imported_count = 0,
    skipped_count = 0,
    collision_count = 0,
    error_count = 0,
    tool_name = "Unknown",
    sarif_file_path = file_path,
    errors = {},
  }

  -- Read SARIF file
  local content = utils.read_file(file_path)
  if not content then
    table.insert(result.errors, "Failed to read SARIF file: " .. file_path)
    return result
  end

  -- Parse SARIF
  local sarif_data, parse_error = M.parse_sarif(content)
  if not sarif_data then
    table.insert(result.errors, parse_error or "Failed to parse SARIF")
    return result
  end

  -- Process each run (typically only one)
  local storage = require("screw.notes.storage")

  -- Temporarily disable auto_save during import to prevent file write/reload cycles
  local backend = storage.get_backend()
  local original_auto_save = backend.config.auto_save
  backend.config.auto_save = false

  local existing_notes = storage.get_all_notes()

  for _, run in ipairs(sarif_data.runs) do
    if run.tool and run.tool.driver then
      result.tool_name = run.tool.driver.name or "Unknown"
    end

    if run.results then
      result.total_findings = result.total_findings + #run.results

      local import_metadata = {
        author = options.author or "sarif-import",
        sarif_file_path = file_path,
        import_timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      }

      for _, sarif_result in ipairs(run.results) do
        local should_continue = false

        -- Apply file filter if specified
        if options.file_filter then
          local location = sarif_result.locations and sarif_result.locations[1]
          if location and location.physicalLocation and location.physicalLocation.artifactLocation then
            local file_uri = location.physicalLocation.artifactLocation.uri
            local file_path_check = resolve_file_path(file_uri, vim.fn.getcwd())

            local should_skip = true
            for _, filter_file in ipairs(options.file_filter) do
              if file_path_check and file_path_check:match(filter_file) then
                should_skip = false
                break
              end
            end

            if should_skip then
              result.skipped_count = result.skipped_count + 1
              should_continue = true
            end
          end
        end

        if not should_continue then
          -- Convert SARIF result to note
          local note = convert_sarif_result_to_note(
            sarif_result,
            run.tool and run.tool.driver and run.tool.driver.rules,
            run.tool and run.tool.driver or {},
            import_metadata
          )

          if not note then
            result.error_count = result.error_count + 1
            table.insert(result.errors, "Failed to convert SARIF result to note")
            should_continue = true
          end

          if not should_continue then
            -- Check for collisions (including exact duplicates by ID)
            local collision_type, existing_note = detect_collision(note, existing_notes)

            -- Also check for exact ID duplicates (prevent importing the same note twice)
            local duplicate_found = false
            for _, existing in ipairs(existing_notes) do
              if existing.id == note.id then
                duplicate_found = true
                break
              end
            end

            if duplicate_found then
              result.skipped_count = result.skipped_count + 1
              should_continue = true
            end

            if not should_continue and collision_type ~= "none" then
              result.collision_count = result.collision_count + 1
              local should_import =
                handle_collision(collision_type, note, existing_note, options.collision_strategy or "ask")

              if not should_import then
                result.skipped_count = result.skipped_count + 1
                should_continue = true
              end
            end

            if not should_continue then
              -- Import the note
              local save_success = storage.save_note(note)
              if save_success then
                result.imported_count = result.imported_count + 1
                -- Note: existing_notes is already updated by save_note since it's the same reference
              else
                result.error_count = result.error_count + 1
                table.insert(result.errors, "Failed to create note for " .. note.file_path .. ":" .. note.line_number)
              end
            end
          end
        end
      end
    end
  end

  -- Restore auto_save setting and force save once at the end
  backend.config.auto_save = original_auto_save
  if result.imported_count > 0 then
    storage.force_save()
  end

  result.success = result.imported_count > 0 or (result.total_findings == 0)
  return result
end

--- Show import results to user
---@param result ScrewImportResult
function M.show_import_results(result)
  local level = result.success and vim.log.levels.INFO or vim.log.levels.ERROR

  local message = string.format(
    [[
SARIF Import %s

✅ Successfully imported: %d notes
⏭️  Skipped: %d notes
⚠️  Collisions handled: %d notes
❌ Errors: %d notes

Total findings processed: %d
Tool: %s
File: %s]],
    result.success and "Complete" or "Failed",
    result.imported_count,
    result.skipped_count,
    result.collision_count,
    result.error_count,
    result.total_findings,
    result.tool_name,
    vim.fn.fnamemodify(result.sarif_file_path, ":t")
  )

  if #result.errors > 0 then
    message = message .. "\n\nErrors:\n" .. table.concat(result.errors, "\n")
  end

  vim.notify(message, level, { title = "SARIF Import" })
end

return M
