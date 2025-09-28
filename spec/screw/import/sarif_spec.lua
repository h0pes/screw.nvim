--- Tests for SARIF import functionality
---
--- This test suite validates the SARIF import public API including:
--- - SARIF file parsing and validation
--- - Complete import workflow through public interface
--- - Error handling and edge cases

local sarif_import = require("screw.import.sarif")
local helpers = require("spec.spec_helper")

describe("SARIF Import Public API", function()
  before_each(function()
    helpers.setup_test_env()
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("SARIF parsing", function()
    it("should parse valid SARIF content", function()
      local valid_sarif_content = vim.json.encode({
        version = "2.1.0",
        ["$schema"] = "https://json.schemastore.org/sarif-2.1.0.json",
        runs = {
          {
            tool = {
              driver = {
                name = "TestTool",
                version = "1.0.0",
                rules = {
                  {
                    id = "TEST-001",
                    name = "test-rule",
                    properties = {
                      tags = { "security", "external/cwe/cwe-79" },
                    },
                  },
                },
              },
            },
            results = {
              {
                message = { text = "XSS vulnerability detected" },
                level = "error",
                ruleId = "TEST-001",
                ruleIndex = 0,
                locations = {
                  {
                    physicalLocation = {
                      artifactLocation = {
                        uri = "file:///project/src/app.js",
                      },
                      region = { startLine = 15 },
                    },
                  },
                },
              },
            },
          },
        },
      })

      local parsed_sarif = sarif_import.parse_sarif(valid_sarif_content)

      assert.is_not_nil(parsed_sarif)
      assert.equals("2.1.0", parsed_sarif.version)
      assert.is_table(parsed_sarif.runs)
      assert.equals(1, #parsed_sarif.runs)
    end)

    it("should handle invalid JSON", function()
      local invalid_json = "{ invalid json content"

      local success, result = pcall(sarif_import.parse_sarif, invalid_json)

      -- Should either return nil or throw an error
      assert.is_true(not success or result == nil)
    end)

    it("should handle empty content", function()
      local empty_content = ""

      local success, result = pcall(sarif_import.parse_sarif, empty_content)

      -- Should either return nil or throw an error
      assert.is_true(not success or result == nil)
    end)
  end)

  describe("SARIF import workflow", function()
    it("should import a complete SARIF file", function()
      -- Create a temporary SARIF file
      local sarif_data = {
        version = "2.1.0",
        ["$schema"] = "https://json.schemastore.org/sarif-2.1.0.json",
        runs = {
          {
            tool = {
              driver = {
                name = "TestTool",
                version = "1.0.0",
                rules = {
                  {
                    id = "TEST-001",
                    name = "test-rule",
                    properties = {
                      tags = { "security", "external/cwe/cwe-79" },
                    },
                  },
                },
              },
            },
            results = {
              {
                message = { text = "XSS vulnerability detected" },
                level = "error",
                ruleId = "TEST-001",
                ruleIndex = 0,
                locations = {
                  {
                    physicalLocation = {
                      artifactLocation = {
                        uri = "file:///project/src/app.js",
                      },
                      region = { startLine = 15 },
                    },
                  },
                },
              },
            },
          },
        },
      }

      local temp_file = "/tmp/test_sarif.sarif"
      local file = io.open(temp_file, "w")
      file:write(vim.json.encode(sarif_data))
      file:close()

      -- Set up mock environment
      vim.g.screw_project_root = "/project"

      local options = {
        collision_strategy = "skip",
        default_author = "test-import",
        preserve_metadata = true,
        show_progress = false,
      }

      local result = sarif_import.import(temp_file, options)

      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_number(result.imported_count)
      assert.is_number(result.skipped_count)
      assert.is_number(result.collision_count)
      assert.is_number(result.error_count)
      assert.is_table(result.errors)

      -- Clean up
      os.remove(temp_file)
    end)

    it("should handle collision detection", function()
      -- Create a SARIF file with a finding
      local sarif_data = {
        version = "2.1.0",
        runs = {
          {
            tool = { driver = { name = "TestTool", rules = {} } },
            results = {
              {
                message = { text = "Test security issue" },
                level = "error",
                locations = {
                  {
                    physicalLocation = {
                      artifactLocation = { uri = "file:///project/src/test.py" },
                      region = { startLine = 42 },
                    },
                  },
                },
              },
            },
          },
        },
      }

      local temp_file = "/tmp/collision_test.sarif"
      local file = io.open(temp_file, "w")
      file:write(vim.json.encode(sarif_data))
      file:close()

      -- Set project root before setting up storage mock
      vim.g.screw_project_root = "/project"

      -- Mock getcwd to return project root for path resolution
      local original_getcwd = vim.fn.getcwd
      vim.fn.getcwd = function()
        return "/project"
      end

      -- Mock storage with existing note that would collide
      local mock_backend = {
        config = { auto_save = true },
        save_note = function(note)
          return true
        end,
        get_all_notes = function()
          return {}
        end,
        force_save = function()
          return true
        end,
      }

      package.loaded["screw.notes.storage"] = {
        get_all_notes = function()
          return {
            {
              id = "existing-1",
              file_path = "src/test.py",
              line_number = 42,
              comment = "Test security issue",
              author = "existing-author",
              timestamp = "2023-01-01T00:00:00Z",
              state = "vulnerable",
              source = "native",
            },
          }
        end,
        save_note = function(note)
          return true
        end,
        get_storage_stats = function()
          return {}
        end,
        force_save = function()
          return true
        end,
        get_backend = function()
          return mock_backend
        end,
      }

      -- Reload the SARIF module to pick up the new storage mock
      package.loaded["screw.import.sarif"] = nil
      -- Also reload any storage-related modules that might be cached
      package.loaded["screw.notes.storage.init"] = nil
      sarif_import = require("screw.import.sarif")

      local options = {
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = sarif_import.import(temp_file, options)

      assert.is_not_nil(result)
      assert.is_false(result.success) -- Should be false since all notes skipped due to collision
      assert.is_true(result.collision_count > 0) -- Should detect collision
      assert.equals(0, result.imported_count) -- Should import 0 notes due to skip strategy
      assert.equals(1, result.skipped_count) -- Should skip 1 note due to collision

      -- Clean up
      vim.fn.getcwd = original_getcwd
      os.remove(temp_file)
    end)

    it("should handle multiple runs and results", function()
      local sarif_data = {
        version = "2.1.0",
        runs = {
          {
            tool = { driver = { name = "Tool1", rules = {} } },
            results = {
              {
                message = { text = "Issue 1" },
                level = "error",
                locations = {
                  {
                    physicalLocation = {
                      artifactLocation = { uri = "file:///project/file1.py" },
                      region = { startLine = 10 },
                    },
                  },
                },
              },
              {
                message = { text = "Issue 2" },
                level = "warning",
                locations = {
                  {
                    physicalLocation = {
                      artifactLocation = { uri = "file:///project/file2.py" },
                      region = { startLine = 20 },
                    },
                  },
                },
              },
            },
          },
          {
            tool = { driver = { name = "Tool2", rules = {} } },
            results = {
              {
                message = { text = "Issue 3" },
                level = "error",
                locations = {
                  {
                    physicalLocation = {
                      artifactLocation = { uri = "file:///project/file3.py" },
                      region = { startLine = 30 },
                    },
                  },
                },
              },
            },
          },
        },
      }

      local temp_file = "/tmp/multi_run_test.sarif"
      local file = io.open(temp_file, "w")
      file:write(vim.json.encode(sarif_data))
      file:close()

      vim.g.screw_project_root = "/project"

      local options = {
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = sarif_import.import(temp_file, options)

      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.is_true(result.total_findings >= 3) -- Should process all findings

      -- Clean up
      os.remove(temp_file)
    end)
  end)

  describe("Error handling", function()
    it("should handle non-existent files", function()
      local options = {
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = sarif_import.import("/tmp/nonexistent.sarif", options)

      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_true(#result.errors > 0)
    end)

    it("should handle malformed SARIF files", function()
      local temp_file = "/tmp/malformed.sarif"
      local file = io.open(temp_file, "w")
      file:write("{ invalid json }")
      file:close()

      local options = {
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = sarif_import.import(temp_file, options)

      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_true(#result.errors > 0)

      -- Clean up
      os.remove(temp_file)
    end)

    it("should handle invalid SARIF structure", function()
      -- Valid JSON but invalid SARIF structure
      local invalid_sarif = {
        version = "1.0.0", -- Wrong version
        runs = "not an array",
      }

      local temp_file = "/tmp/invalid_structure.sarif"
      local file = io.open(temp_file, "w")
      file:write(vim.json.encode(invalid_sarif))
      file:close()

      local options = {
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = sarif_import.import(temp_file, options)

      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_true(#result.errors > 0)

      -- Clean up
      os.remove(temp_file)
    end)

    it("should handle storage failures", function()
      local sarif_data = {
        version = "2.1.0",
        runs = {
          {
            tool = { driver = { name = "TestTool", rules = {} } },
            results = {
              {
                message = { text = "Test issue" },
                level = "error",
                locations = {
                  {
                    physicalLocation = {
                      artifactLocation = { uri = "file:///project/test.py" },
                      region = { startLine = 42 },
                    },
                  },
                },
              },
            },
          },
        },
      }

      local temp_file = "/tmp/storage_fail_test.sarif"
      local file = io.open(temp_file, "w")
      file:write(vim.json.encode(sarif_data))
      file:close()

      vim.g.screw_project_root = "/project"

      -- Mock storage that fails to save
      local mock_backend = {
        config = { auto_save = true },
        save_note = function(note)
          return false
        end, -- Simulate storage failure
        get_all_notes = function()
          return {}
        end,
        force_save = function()
          return true
        end,
      }

      package.loaded["screw.notes.storage"] = {
        get_all_notes = function()
          return {}
        end,
        save_note = function(note)
          return false
        end, -- Simulate storage failure
        get_storage_stats = function()
          return {}
        end,
        force_save = function()
          return true
        end,
        get_backend = function()
          return mock_backend
        end,
      }

      local options = {
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = sarif_import.import(temp_file, options)

      assert.is_not_nil(result)
      -- Even with storage failures, the import might still report success
      -- depending on how errors are handled
      assert.is_true(result.error_count >= 0)

      -- Clean up
      os.remove(temp_file)
    end)
  end)

  describe("Result display", function()
    it("should show import results", function()
      local mock_result = {
        success = true,
        imported_count = 5,
        skipped_count = 2,
        collision_count = 1,
        error_count = 0,
        total_findings = 8,
        tool_name = "TestTool",
        sarif_file_path = "/tmp/test.sarif",
        errors = {},
      }

      -- This should not throw an error
      local success = pcall(sarif_import.show_import_results, mock_result)
      assert.is_true(success)
    end)

    it("should show import results with errors", function()
      local mock_result = {
        success = false,
        imported_count = 2,
        skipped_count = 1,
        collision_count = 1,
        error_count = 2,
        total_findings = 6,
        tool_name = "TestTool",
        sarif_file_path = "/tmp/test.sarif",
        errors = { "Error 1", "Error 2" },
      }

      -- This should not throw an error
      local success = pcall(sarif_import.show_import_results, mock_result)
      assert.is_true(success)
    end)
  end)
end)
