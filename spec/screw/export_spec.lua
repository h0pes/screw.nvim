--- Tests for the main export module
---
--- This test suite validates the export module's interface and
--- integration with different export formats (CSV, JSON, Markdown, SARIF).
---

local helpers = require("spec.spec_helper")

describe("screw.export", function()
  local export_module
  local mock_notes

  before_each(function()
    helpers.setup_test_env()

    -- Clear any previous export module mocks
    package.loaded["screw.export.csv"] = nil
    package.loaded["screw.export.json"] = nil
    package.loaded["screw.export.markdown"] = nil
    package.loaded["screw.export.sarif"] = nil

    -- Mock storage module
    package.loaded["screw.notes.storage"] = {
      get_all_notes = function()
        return mock_notes or {}
      end,
    }

    -- Mock config module
    package.loaded["screw.config"] = {
      get_option = function(key)
        if key == "export" then
          return {
            output_dir = "/tmp/screw_test/exports",
            default_format = "markdown",
          }
        end
        return nil
      end,
    }

    -- Mock utils functions
    package.loaded["screw.utils"] = {
      get_project_root = function()
        return "/tmp/test-project"
      end,
      ensure_dir = function()
        return true
      end,
      write_file = function()
        return true -- Default to successful write
      end,
      get_timestamp = function()
        return "2024-01-01T00:00:00Z"
      end,
      get_absolute_path = function(relative_path)
        return "/tmp/test-project/" .. relative_path
      end,
      info = function() end,
      warn = function() end,
      error = function() end,
    }

    -- Create test notes
    mock_notes = helpers.create_mock_notes(3)
    mock_notes[1].state = "vulnerable"
    mock_notes[1].severity = "high"
    mock_notes[1].cwe = "CWE-79"
    mock_notes[2].state = "not_vulnerable"
    mock_notes[2].severity = "low"
    mock_notes[3].state = "todo"

    -- Reset module
    package.loaded["screw.export.init"] = nil
    export_module = require("screw.export.init")
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("export_notes", function()
    it("should export to CSV format", function()
      local options = {
        format = "csv",
        output_path = "/tmp/test_export.csv",
      }

      local success = export_module.export_notes(options)

      assert.is_true(success)
    end)

    it("should export to JSON format", function()
      local options = {
        format = "json",
        output_path = "/tmp/test_export.json",
      }

      local success = export_module.export_notes(options)

      assert.is_true(success)
    end)

    it("should export to Markdown format", function()
      local options = {
        format = "markdown",
        output_path = "/tmp/test_export.md",
      }

      local success = export_module.export_notes(options)

      assert.is_true(success)
    end)

    it("should export to SARIF format", function()
      local options = {
        format = "sarif",
        output_path = "/tmp/test_export.sarif",
      }

      local success = export_module.export_notes(options)

      assert.is_true(success)
    end)

    it("should handle unsupported format", function()
      local options = {
        format = "unsupported",
        output_path = "/tmp/test_export.txt",
      }

      local success = export_module.export_notes(options)

      assert.is_false(success)
    end)

    it("should use default output path when not specified", function()
      local options = {
        format = "csv",
        -- Missing output_path - should use default
      }

      local success = export_module.export_notes(options)

      assert.is_true(success)
    end)

    it("should handle export failure", function()
      package.loaded["screw.utils"].write_file = function()
        return false -- Simulate write failure
      end

      local options = {
        format = "csv",
        output_path = "/tmp/test_export.csv",
      }

      local success = export_module.export_notes(options)

      assert.is_false(success)
    end)

    it("should apply filters when specified", function()
      local filter_called = false

      -- Mock CSV exporter to check if filter was applied
      package.loaded["screw.export.csv"] = {
        export = function(notes, options)
          filter_called = true
          -- Should receive filtered notes
          assert.equal(1, #notes) -- Only vulnerable notes
          return "mock csv content"
        end,
      }

      local options = {
        format = "csv",
        output_path = "/tmp/filtered_export.csv",
        filter = { state = "vulnerable" },
      }

      export_module.export_notes(options)

      assert.is_true(filter_called)
    end)

    it("should handle empty note collection", function()
      mock_notes = {}

      local options = {
        format = "csv",
        output_path = "/tmp/empty_export.csv",
      }

      local success = export_module.export_notes(options)

      assert.is_true(success)
    end)
  end)

  describe("format validation", function()
    it("should accept valid formats", function()
      local valid_formats = { "csv", "json", "markdown", "sarif" }

      for _, format in ipairs(valid_formats) do
        local options = {
          format = format,
          output_path = "/tmp/test." .. format,
        }

        local success = export_module.export_notes(options)
        assert.is_true(success, "Format " .. format .. " should be supported")
      end
    end)

    it("should reject invalid formats", function()
      local invalid_formats = { "xml", "yaml", "txt", "" }

      for _, format in ipairs(invalid_formats) do
        local options = {
          format = format,
          output_path = "/tmp/test." .. format,
        }

        local success = export_module.export_notes(options)
        assert.is_false(success, "Format " .. format .. " should be rejected")
      end
    end)
  end)

  describe("error handling", function()
    it("should handle missing format", function()
      local options = {
        output_path = "/tmp/test_export.csv",
        -- Missing format
      }

      local success = export_module.export_notes(options)

      assert.is_false(success)
    end)

    it("should handle nil options", function()
      local success = export_module.export_notes(nil)

      assert.is_false(success)
    end)

    it("should handle invalid output path", function()
      local options = {
        format = "csv",
        output_path = "/invalid/path/that/does/not/exist/file.csv",
      }

      package.loaded["screw.utils"].write_file = function()
        return false -- Simulate path failure
      end

      local success = export_module.export_notes(options)

      assert.is_false(success)
    end)
  end)

  describe("integration", function()
    it("should work with real note data", function()
      -- Use actual note structure
      mock_notes = {
        {
          id = "real-note-1",
          file_path = "src/auth.lua",
          line_number = 42,
          author = "security-team",
          timestamp = "2024-01-01T10:00:00Z",
          comment = "Potential authentication bypass",
          description = "User input is not properly validated before authentication",
          cwe = "CWE-287",
          state = "vulnerable",
          severity = "high",
          replies = {
            {
              id = "reply-1",
              parent_id = "real-note-1",
              author = "developer",
              timestamp = "2024-01-01T11:00:00Z",
              comment = "Working on a fix",
            },
          },
        },
      }

      local options = {
        format = "json",
        output_path = "/tmp/real_export.json",
      }

      local success = export_module.export_notes(options)

      assert.is_true(success)
    end)

    it("should preserve note metadata", function()
      local export_called = false
      local exported_notes = nil

      package.loaded["screw.export.json"] = {
        export = function(notes, options)
          export_called = true
          exported_notes = notes
          return "mock json content"
        end,
      }

      local options = {
        format = "json",
        output_path = "/tmp/metadata_test.json",
      }

      export_module.export_notes(options)

      assert.is_true(export_called)
      assert.is_table(exported_notes)
      assert.equal(3, #exported_notes)

      -- Check that all metadata is preserved
      local note = exported_notes[1]
      assert.is_string(note.id)
      assert.is_string(note.file_path)
      assert.is_number(note.line_number)
      assert.is_string(note.author)
      assert.is_string(note.timestamp)
      assert.is_string(note.comment)
      assert.is_string(note.state)
    end)
  end)
end)
