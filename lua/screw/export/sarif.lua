--- SARIF exporter for screw.nvim
---
--- This module exports security notes to SARIF (Static Analysis Results Interchange Format) v2.1.0
--- SARIF spec: https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html
---

local utils = require("screw.utils")

local M = {}

--- Convert screw state to SARIF level
---@param state string
---@param severity string?
---@return string
local function state_to_sarif_level(state, severity)
  if state == "vulnerable" then
    if severity == "high" then
      return "error"
    elseif severity == "medium" then
      return "warning"
    else
      return "note"
    end
  elseif state == "not_vulnerable" then
    return "none"
  else -- todo
    return "note"
  end
end

--- Convert screw state to SARIF kind
---@param state string
---@return string
local function state_to_sarif_kind(state)
  if state == "vulnerable" then
    return "fail"
  elseif state == "not_vulnerable" then
    return "pass"
  else -- todo
    return "review"
  end
end

--- Generate a rule ID from CWE or state
---@param note ScrewNote
---@return string
local function generate_rule_id(note)
  if note.cwe then
    return note.cwe
  else
    return "SCREW-" .. string.upper(note.state)
  end
end

--- Create SARIF rule descriptor
---@param rule_id string
---@param notes ScrewNote[]
---@return table
local function create_rule_descriptor(rule_id, notes)
  -- Find a representative note for this rule
  local representative_note = notes[1]
  for _, note in ipairs(notes) do
    if note.cwe == rule_id or generate_rule_id(note) == rule_id then
      representative_note = note
      break
    end
  end
  
  local rule = {
    id = rule_id,
    name = rule_id,
    shortDescription = {
      text = "Security Finding: " .. rule_id
    },
    fullDescription = {
      text = representative_note.description or representative_note.comment
    },
    defaultConfiguration = {
      level = state_to_sarif_level(representative_note.state, representative_note.severity)
    },
    properties = {
      tags = { "security" }
    }
  }
  
  -- Add CWE-specific information if available
  if rule_id:match("^CWE%-") then
    rule.properties.tags = { "security", "CWE" }
    rule.relationships = {
      {
        target = {
          id = rule_id,
          guid = rule_id,
          toolComponent = {
            name = "CWE",
            version = "4.8",
            guid = "fd4a7c42-8a9d-4e5f-a5f1-8f7c1f1b8c8d"
          }
        },
        kinds = { "superset" }
      }
    }
  end
  
  return rule
end

--- Create SARIF location object
---@param note ScrewNote
---@return table
local function create_location(note)
  return {
    physicalLocation = {
      artifactLocation = {
        uri = note.file_path,
        uriBaseId = "%SRCROOT%"
      },
      region = {
        startLine = note.line_number,
        startColumn = 1,
        endLine = note.line_number,
        endColumn = 1
      }
    }
  }
end

--- Create SARIF result object
---@param note ScrewNote
---@return table
local function create_result(note)
  local rule_id = generate_rule_id(note)
  local result = {
    ruleId = rule_id,
    ruleIndex = 0, -- Will be updated when we know the actual index
    message = {
      text = note.comment
    },
    locations = { create_location(note) },
    level = state_to_sarif_level(note.state, note.severity),
    kind = state_to_sarif_kind(note.state),
    properties = {
      author = note.author,
      timestamp = note.timestamp,
      state = note.state
    }
  }
  
  -- Add optional fields if present
  if note.description then
    result.message.markdown = note.description
  end
  
  if note.severity then
    result.properties.severity = note.severity
  end
  
  if note.updated_at then
    result.properties.updated_at = note.updated_at
  end
  
  -- Add thread information if replies exist
  if note.replies and #note.replies > 0 then
    result.properties.replies_count = #note.replies
    result.properties.thread = {}
    for i, reply in ipairs(note.replies) do
      table.insert(result.properties.thread, {
        author = reply.author,
        timestamp = reply.timestamp,
        comment = reply.comment
      })
    end
  end
  
  return result
end

--- Export notes to SARIF format
---@param notes ScrewNote[]
---@param options ScrewExportOptions
---@return string?
function M.export(notes, options)
  if not notes or #notes == 0 then
    return nil
  end
  
  -- Group notes by rule ID to create rule descriptors
  local rules_map = {}
  local results = {}
  
  for _, note in ipairs(notes) do
    local rule_id = generate_rule_id(note)
    if not rules_map[rule_id] then
      rules_map[rule_id] = {}
    end
    table.insert(rules_map[rule_id], note)
    table.insert(results, create_result(note))
  end
  
  -- Create rule descriptors
  local rules = {}
  local rule_index_map = {}
  local index = 0
  
  for rule_id, rule_notes in pairs(rules_map) do
    table.insert(rules, create_rule_descriptor(rule_id, rule_notes))
    rule_index_map[rule_id] = index
    index = index + 1
  end
  
  -- Update ruleIndex in results
  for _, result in ipairs(results) do
    result.ruleIndex = rule_index_map[result.ruleId]
  end
  
  -- Create SARIF log structure
  local sarif_log = {
    ["$schema"] = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
    version = "2.1.0",
    runs = {
      {
        tool = {
          driver = {
            name = "screw.nvim",
            version = "1.0.0",
            informationUri = "https://github.com/h0pes/screw.nvim",
            shortDescription = {
              text = "Security code review plugin for Neovim"
            },
            fullDescription = {
              text = "A Neovim plugin designed to streamline security code reviews with comprehensive note-taking capabilities, CWE classification, and collaboration features."
            },
            rules = rules,
            properties = {
              generator = "screw.nvim",
              exportTimestamp = utils.get_timestamp()
            }
          }
        },
        results = results,
        columnKind = "utf16CodeUnits",
        properties = {
          exportOptions = {
            includeReplies = options.include_replies ~= false,
            filter = options.filter
          },
          statistics = {
            totalNotes = #notes,
            totalRules = #rules,
            vulnerableCount = 0,
            notVulnerableCount = 0,
            todoCount = 0
          }
        }
      }
    }
  }
  
  -- Calculate statistics
  local stats = sarif_log.runs[1].properties.statistics
  for _, note in ipairs(notes) do
    if note.state == "vulnerable" then
      stats.vulnerableCount = stats.vulnerableCount + 1
    elseif note.state == "not_vulnerable" then
      stats.notVulnerableCount = stats.notVulnerableCount + 1
    else
      stats.todoCount = stats.todoCount + 1
    end
  end
  
  -- Convert to JSON
  local success, json_content = pcall(vim.json.encode, sarif_log)
  if not success then
    utils.error("Failed to encode SARIF JSON: " .. tostring(json_content))
    return nil
  end
  
  return json_content
end

--- Get SARIF format description
---@return table
function M.get_format_info()
  return {
    name = "SARIF",
    description = "Static Analysis Results Interchange Format v2.1.0",
    extension = "sarif",
    mime_type = "application/sarif+json",
    specification = "https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html"
  }
end

return M