--- Tests for the main import module
---
--- This test suite validates the import module's interface and
--- integration with different import formats (currently SARIF).
---

local import_module = require("screw.import.init")
local helpers = require("spec.spec_helper")

describe("Import Module", function()
  before_each(function()
    helpers.setup_test_env()
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("SARIF import interface", function()
    it("should import SARIF from file", function()
      -- Create a temporary SARIF file
      local sarif_content = vim.json.encode({
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

      local temp_file = "/tmp/test_sarif.sarif"
      local file = io.open(temp_file, "w")
      file:write(sarif_content)
      file:close()

      -- Set up mock environment
      vim.g.screw_project_root = "/project"

      -- Mock storage
      local storage = require("screw.notes.storage")
      storage.get_all_notes = function()
        return {}
      end
      storage.save_note = function(note)
        return true
      end

      local options = {
        format = "sarif",
        input_path = temp_file,
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = import_module.import_sarif(options)

      assert.is_not_nil(result)
      assert.is_true(result.success)
      assert.equals(1, result.imported_count)
      assert.equals(0, result.collision_count)
      assert.equals(0, #result.errors)

      -- Clean up
      os.remove(temp_file)
    end)

    it("should handle missing input file", function()
      local options = {
        format = "sarif",
        input_path = "/tmp/nonexistent.sarif",
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = import_module.import_sarif(options)

      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_true(result.total_imported == 0 or result.total_imported == nil)
      assert.is_true(#result.errors > 0)
    end)

    it("should validate required options", function()
      local incomplete_options = {
        format = "sarif",
        -- Missing input_path
      }

      local result = import_module.import_sarif(incomplete_options)

      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_true(#result.errors > 0)
      assert.matches("Input path is required", result.errors[1])
    end)

    it("should use default collision strategy", function()
      -- Create a simple SARIF file
      local sarif_content = vim.json.encode({
        version = "2.1.0",
        runs = {
          {
            tool = { driver = { name = "TestTool", rules = {} } },
            results = {},
          },
        },
      })

      local temp_file = "/tmp/empty_sarif.sarif"
      local file = io.open(temp_file, "w")
      file:write(sarif_content)
      file:close()

      local options = {
        format = "sarif",
        input_path = temp_file,
        -- No collision_strategy specified, should use default
      }

      local result = import_module.import_sarif(options)

      assert.is_not_nil(result)
      assert.is_true(result.success)

      -- Clean up
      os.remove(temp_file)
    end)
  end)

  describe("Configuration integration", function()
    it("should use default configuration values", function()
      local config = require("screw.config")
      local default_config = config.get()

      -- Create minimal SARIF
      local sarif_content = vim.json.encode({
        version = "2.1.0",
        runs = {
          {
            tool = { driver = { name = "TestTool", rules = {} } },
            results = {},
          },
        },
      })

      local temp_file = "/tmp/config_test.sarif"
      local file = io.open(temp_file, "w")
      file:write(sarif_content)
      file:close()

      local options = {
        format = "sarif",
        input_path = temp_file,
      }

      local result = import_module.import_sarif(options)

      assert.is_not_nil(result)
      assert.is_true(result.success)

      -- Clean up
      os.remove(temp_file)
    end)
  end)

  describe("Error handling", function()
    it("should handle malformed SARIF files", function()
      local temp_file = "/tmp/malformed.sarif"
      local file = io.open(temp_file, "w")
      file:write("{ invalid json content")
      file:close()

      local options = {
        format = "sarif",
        input_path = temp_file,
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = import_module.import_sarif(options)

      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_true(result.total_imported == 0 or result.total_imported == nil)
      assert.is_true(#result.errors > 0)

      -- Clean up
      os.remove(temp_file)
    end)

    it("should handle permission errors", function()
      local options = {
        format = "sarif",
        input_path = "/root/restricted.sarif", -- Likely inaccessible
        collision_strategy = "skip",
        default_author = "test-import",
      }

      local result = import_module.import_sarif(options)

      assert.is_not_nil(result)
      assert.is_false(result.success)
      assert.is_true(result.total_imported == 0 or result.total_imported == nil)
      assert.is_true(#result.errors > 0)
    end)
  end)
end)
