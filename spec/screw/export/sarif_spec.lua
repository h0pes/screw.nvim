local helpers = require("spec.spec_helper")

describe("screw.export.sarif", function()
  local sarif_exporter

  before_each(function()
    helpers.setup_test_env()
    sarif_exporter = require("screw.export.sarif")
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("export", function()
    it("should export single note to SARIF", function()
      local notes = { helpers.create_mock_note() }
      local options = { include_replies = true }

      local result = sarif_exporter.export(notes, options)

      assert.is_string(result)

      -- Parse JSON to validate structure
      local sarif_data = vim.json.decode(result)
      assert.is_table(sarif_data)
      assert.equal(sarif_data.version, "2.1.0")
      assert.is_table(sarif_data.runs)
      assert.equal(#sarif_data.runs, 1)

      local run = sarif_data.runs[1]
      assert.is_table(run.tool)
      assert.equal(run.tool.driver.name, "screw.nvim")
      assert.is_table(run.results)
      assert.equal(#run.results, 1)

      local result_obj = run.results[1]
      assert.equal(result_obj.ruleId, "CWE-79")
      assert.equal(result_obj.level, "error")
      assert.equal(result_obj.kind, "fail")
      assert.is_table(result_obj.locations)
      assert.equal(#result_obj.locations, 1)
    end)

    it("should export multiple notes to SARIF", function()
      local notes = helpers.create_mock_notes(3)
      local options = { include_replies = true }

      local result = sarif_exporter.export(notes, options)

      assert.is_string(result)

      local sarif_data = vim.json.decode(result)
      local run = sarif_data.runs[1]
      assert.equal(#run.results, 3)
    end)

    it("should handle notes without CWE", function()
      local note = helpers.create_mock_note({
        state = "todo",
      })
      -- Explicitly set cwe to nil after creation
      note.cwe = nil
      local notes = { note }
      local options = { include_replies = true }

      local result = sarif_exporter.export(notes, options)

      assert.is_string(result)

      local sarif_data = vim.json.decode(result)
      local run = sarif_data.runs[1]
      local result_obj = run.results[1]
      assert.equal(result_obj.ruleId, "SCREW-TODO")
      assert.equal(result_obj.level, "note")
      assert.equal(result_obj.kind, "review")
    end)

    it("should handle notes with replies", function()
      local note = helpers.create_mock_note({
        replies = {
          {
            id = "reply-1",
            parent_id = "test-note-123",
            author = "reviewer",
            timestamp = "2024-01-01T01:00:00Z",
            comment = "This is a reply",
          },
        },
      })
      local notes = { note }
      local options = { include_replies = true }

      local result = sarif_exporter.export(notes, options)

      assert.is_string(result)

      local sarif_data = vim.json.decode(result)
      local run = sarif_data.runs[1]
      local result_obj = run.results[1]
      assert.equal(result_obj.properties.replies_count, 1)
      assert.is_table(result_obj.properties.thread)
      assert.equal(#result_obj.properties.thread, 1)
    end)

    it("should map vulnerability states to SARIF levels correctly", function()
      local notes = {
        helpers.create_mock_note({ state = "vulnerable", severity = "high" }),
        helpers.create_mock_note({ state = "vulnerable", severity = "medium" }),
        helpers.create_mock_note({ state = "vulnerable", severity = "low" }),
        helpers.create_mock_note({ state = "not_vulnerable" }),
        helpers.create_mock_note({ state = "todo" }),
      }
      local options = { include_replies = true }

      local result = sarif_exporter.export(notes, options)

      assert.is_string(result)

      local sarif_data = vim.json.decode(result)
      local run = sarif_data.runs[1]
      local results = run.results

      -- Check level mappings
      assert.equal(results[1].level, "error") -- vulnerable + high
      assert.equal(results[2].level, "warning") -- vulnerable + medium
      assert.equal(results[3].level, "note") -- vulnerable + low
      assert.equal(results[4].level, "none") -- not_vulnerable
      assert.equal(results[5].level, "note") -- todo
    end)

    it("should map vulnerability states to SARIF kinds correctly", function()
      local notes = {
        helpers.create_mock_note({ state = "vulnerable" }),
        helpers.create_mock_note({ state = "not_vulnerable" }),
        helpers.create_mock_note({ state = "todo" }),
      }
      local options = { include_replies = true }

      local result = sarif_exporter.export(notes, options)

      assert.is_string(result)

      local sarif_data = vim.json.decode(result)
      local run = sarif_data.runs[1]
      local results = run.results

      -- Check kind mappings
      assert.equal(results[1].kind, "fail") -- vulnerable
      assert.equal(results[2].kind, "pass") -- not_vulnerable
      assert.equal(results[3].kind, "review") -- todo
    end)

    it("should include proper location information", function()
      local note = helpers.create_mock_note({
        file_path = "src/test.lua",
        line_number = 42,
      })
      local notes = { note }
      local options = { include_replies = true }

      local result = sarif_exporter.export(notes, options)

      assert.is_string(result)

      local sarif_data = vim.json.decode(result)
      local run = sarif_data.runs[1]
      local result_obj = run.results[1]
      local location = result_obj.locations[1]

      assert.equal(location.physicalLocation.artifactLocation.uri, "src/test.lua")
      assert.equal(location.physicalLocation.region.startLine, 42)
    end)

    it("should return nil for empty notes", function()
      local result = sarif_exporter.export({}, {})

      assert.is_nil(result)
    end)

    it("should return nil for nil notes", function()
      local result = sarif_exporter.export(nil, {})

      assert.is_nil(result)
    end)
  end)

  describe("get_format_info", function()
    it("should return format information", function()
      local info = sarif_exporter.get_format_info()

      assert.is_table(info)
      assert.equal(info.name, "SARIF")
      assert.equal(info.extension, "sarif")
      assert.equal(info.mime_type, "application/sarif+json")
      assert.is_string(info.description)
      assert.is_string(info.specification)
    end)
  end)
end)
