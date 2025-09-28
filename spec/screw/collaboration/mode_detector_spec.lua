--- Tests for the collaboration mode detector
---
--- This test suite validates the automatic mode detection logic,
--- user choice handling, and configuration application.
---

local helpers = require("spec.spec_helper")

describe("screw.collaboration.mode_detector", function()
  local ModeDetector
  local original_env = {}

  before_each(function()
    helpers.setup_test_env()

    -- Store original environment
    original_env.SCREW_API_URL = os.getenv("SCREW_API_URL")
    original_env.SCREW_USER_EMAIL = os.getenv("SCREW_USER_EMAIL")
    original_env.SCREW_USER_ID = os.getenv("SCREW_USER_ID")

    -- Clear environment for clean testing
    for key, _ in pairs(original_env) do
      vim.env[key] = nil
    end

    -- Mock project root
    vim.g.screw_project_root = "/tmp/test-project"

    -- Create mutable config object for testing
    local test_config = {
      storage = { backend = "json" },
      collaboration = {
        enabled = false,
        api_url = nil,
        user_id = nil,
      },
    }

    -- Mock config module
    package.loaded["screw.config"] = {
      get = function()
        return test_config
      end,
      get_option = function(option)
        if option == "storage.backend" then
          return test_config.storage.backend
        elseif option == "collaboration.enabled" then
          return test_config.collaboration.enabled
        end
        return nil
      end,
    }

    -- Mock utils module
    package.loaded["screw.utils"] = {
      get_project_root = function()
        return "/tmp/test-project"
      end,
      info = function() end,
      error = function() end,
      collaboration_status = function() end,
    }

    -- Mock HTTP backend
    package.loaded["screw.notes.storage.http"] = {
      new = function()
        return {
          connect = function()
            return false, "connection failed" -- Default to no connection
          end,
          disconnect = function() end,
          load_notes = function()
            return {} -- Default to no notes
          end,
        }
      end,
    }

    -- Mock file system operations
    vim.fn.glob = function(pattern, nosuf, list)
      return {} -- Default to no files
    end

    vim.fn.readfile = function(file)
      error("File not found") -- Default file read failure
    end

    -- Reset the module
    package.loaded["screw.collaboration.mode_detector"] = nil
    ModeDetector = require("screw.collaboration.mode_detector")
  end)

  after_each(function()
    helpers.cleanup_test_files()

    -- Restore environment
    for key, value in pairs(original_env) do
      vim.env[key] = value
    end
  end)

  describe("detect_mode", function()
    describe("with no existing data", function()
      it("should default to local mode when no API available", function()
        local result = ModeDetector.detect_mode()

        assert.equal("local", result.mode)
        assert.equal("new project, no database available", result.reason)
        assert.is_false(result.requires_migration)
        assert.is_false(result.local_notes_found)
        assert.is_false(result.db_available)
        assert.is_false(result.db_notes_found)
      end)

      it("should prompt user when API is available but no notes exist", function()
        -- Mock API availability
        os.getenv = function(var)
          if var == "SCREW_API_URL" then
            return "http://localhost:3000/api"
          end
          return nil
        end

        package.loaded["screw.notes.storage.http"].new = function()
          return {
            connect = function()
              return true -- Connection succeeds
            end,
            disconnect = function() end,
            load_notes = function()
              return {} -- No notes from API
            end,
          }
        end

        -- Mock user choice
        vim.fn.confirm = function()
          return 1 -- Choose Local
        end

        local result = ModeDetector.detect_mode()

        assert.equal("local", result.mode)
        assert.equal("user chose local for new project", result.reason)
        assert.is_false(result.requires_migration)
        assert.is_false(result.local_notes_found)
        assert.is_true(result.db_available)
        assert.is_false(result.db_notes_found)
        assert.equal("local", result.user_choice)
      end)

      it("should choose collaborative mode when user prefers it", function()
        os.getenv = function(var)
          if var == "SCREW_API_URL" then
            return "http://localhost:3000/api"
          end
          return nil
        end

        package.loaded["screw.notes.storage.http"].new = function()
          return {
            connect = function()
              return true
            end,
            disconnect = function() end,
            load_notes = function()
              return {} -- No notes from API
            end,
          }
        end

        vim.fn.confirm = function()
          return 2 -- Choose Collaborative
        end

        local result = ModeDetector.detect_mode()

        assert.equal("collaborative", result.mode)
        assert.equal("user chose collaborative for new project", result.reason)
      end)
    end)

    describe("with existing local notes", function()
      before_each(function()
        -- Mock existing local JSON files
        vim.fn.glob = function(pattern, nosuf, list)
          if pattern:match("screw_notes_.*.json") then
            return { "/tmp/test-project/screw_notes_123.json" }
          elseif pattern:match("%.db") then
            return {} -- No sqlite files
          end
          return {}
        end

        vim.fn.readfile = function(file)
          return { '{"notes": [{"id": "note1"}, {"id": "note2"}]}' }
        end
      end)

      it("should use local mode when no database available", function()
        local result = ModeDetector.detect_mode()

        assert.equal("local", result.mode)
        assert.equal("local notes found, no database available", result.reason)
        assert.is_true(result.local_notes_found)
        assert.is_false(result.db_available)
        assert.equal(2, result.local_count)
      end)

      it("should prompt for migration when database is available", function()
        vim.env.SCREW_API_URL = "http://localhost:3000/api"
        package.loaded["screw.notes.storage.http"].new = function()
          return {
            connect = function()
              return true
            end,
            disconnect = function() end,
            load_notes = function()
              return {} -- No notes from API
            end,
          }
        end

        vim.fn.confirm = function()
          return 3 -- Choose "Migrate to DB"
        end

        local result = ModeDetector.detect_mode()

        assert.equal("collaborative", result.mode)
        assert.equal("user chose to migrate local notes to database", result.reason)
        assert.is_true(result.requires_migration)
        assert.equal("migrate_to_db", result.user_choice)
      end)

      it("should continue local mode when user chooses to stay local", function()
        vim.env.SCREW_API_URL = "http://localhost:3000/api"
        package.loaded["screw.notes.storage.http"].new = function()
          return {
            connect = function()
              return true
            end,
            disconnect = function() end,
            load_notes = function()
              return {} -- No notes from API
            end,
          }
        end

        vim.fn.confirm = function()
          return 1 -- Choose "Local"
        end

        local result = ModeDetector.detect_mode()

        assert.equal("local", result.mode)
        assert.equal("user chose to continue with local notes", result.reason)
        assert.is_false(result.requires_migration)
      end)
    end)

    describe("with existing database notes", function()
      before_each(function()
        vim.env.SCREW_API_URL = "http://localhost:3000/api"
        package.loaded["screw.notes.storage.http"].new = function()
          return {
            connect = function()
              return true
            end,
            disconnect = function() end,
            load_notes = function()
              return { { id = "1" }, { id = "2" }, { id = "3" }, { id = "4" }, { id = "5" } } -- 5 notes in DB
            end,
          }
        end
      end)

      it("should automatically use collaborative mode", function()
        local result = ModeDetector.detect_mode()

        assert.equal("collaborative", result.mode)
        assert.equal("database notes found, continuing in collaborative mode", result.reason)
        assert.is_false(result.requires_migration)
        assert.is_false(result.local_notes_found)
        assert.is_true(result.db_available)
        assert.is_true(result.db_notes_found)
        assert.equal(5, result.db_count)
      end)
    end)

    describe("with both local and database notes", function()
      before_each(function()
        -- Mock local notes
        vim.fn.glob = function(pattern)
          if pattern:match("screw_notes_.*.json") then
            return { "/tmp/test-project/screw_notes_123.json" }
          end
          return {}
        end

        vim.fn.readfile = function(file)
          return { '{"notes": [{"id": "note1"}, {"id": "note2"}]}' }
        end

        -- Mock API notes
        os.getenv = function(var)
          if var == "SCREW_API_URL" then
            return "http://localhost:3000/api"
          end
          return nil
        end

        package.loaded["screw.notes.storage.http"].new = function()
          return {
            connect = function()
              return true
            end,
            disconnect = function() end,
            load_notes = function()
              -- Return 3 notes from API
              return { { id = "1" }, { id = "2" }, { id = "3" } }
            end,
          }
        end
      end)

      it("should prompt user for conflict resolution", function()
        vim.fn.confirm = function()
          return 2 -- Choose "Collaborative"
        end

        local result = ModeDetector.detect_mode()

        assert.equal("collaborative", result.mode)
        assert.equal("user chose collaborative with existing data in both locations", result.reason)
        assert.is_true(result.local_notes_found)
        assert.is_true(result.db_notes_found)
        assert.equal("collaborative", result.user_choice)
      end)

      it("should handle export from database to local", function()
        vim.fn.confirm = function()
          return 4 -- Choose "Export from DB"
        end

        local result = ModeDetector.detect_mode()

        assert.equal("local", result.mode)
        assert.equal("user chose to export database notes to local", result.reason)
        assert.is_true(result.requires_migration)
        assert.equal("export_from_db", result.user_choice)
      end)

      it("should handle user cancellation", function()
        vim.fn.confirm = function()
          return 5 -- Choose "Cancel"
        end

        local result = ModeDetector.detect_mode()

        assert.equal("local", result.mode)
        assert.equal("user cancelled choice, defaulted to local", result.reason)
        assert.is_false(result.requires_migration)
      end)
    end)

    describe("error handling", function()
      it("should handle JSON parsing errors", function()
        vim.fn.glob = function(pattern)
          if pattern:match("screw_notes_.*.json") then
            return { "/tmp/test-project/invalid.json" }
          end
          return {}
        end

        vim.fn.readfile = function(file)
          return { "invalid json content" }
        end

        local result = ModeDetector.detect_mode()

        -- Should not crash and default to no local notes
        assert.is_false(result.local_notes_found)
      end)

      it("should handle API connection failures", function()
        os.getenv = function(var)
          if var == "SCREW_API_URL" then
            return "http://invalid:9999/api"
          end
          return nil
        end

        local result = ModeDetector.detect_mode()

        assert.is_false(result.db_available)
        assert.is_false(result.db_notes_found)
      end)

      it("should handle API with no notes", function()
        os.getenv = function(var)
          if var == "SCREW_API_URL" then
            return "http://localhost:3000/api"
          end
          return nil
        end

        package.loaded["screw.notes.storage.http"].new = function()
          return {
            connect = function()
              return true
            end,
            disconnect = function() end,
            load_notes = function()
              return {} -- No notes from API
            end,
          }
        end

        local result = ModeDetector.detect_mode()

        assert.is_true(result.db_available)
        assert.is_false(result.db_notes_found)
        assert.equal(0, result.db_count)
      end)
    end)
  end)

  describe("apply_mode", function()
    it("should configure collaborative mode correctly", function()
      -- Mock os.getenv for HTTP collaboration
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_API_URL" then
          return "http://localhost:3000/api"
        elseif var == "SCREW_USER_EMAIL" then
          return "test@example.com"
        else
          return original_getenv(var)
        end
      end

      local config = package.loaded["screw.config"].get()

      local detection_result = {
        mode = "collaborative",
        reason = "test",
        requires_migration = false,
      }

      local success = ModeDetector.apply_mode(detection_result)

      assert.is_true(success)
      assert.equal("http", config.storage.backend)
      assert.is_true(config.collaboration.enabled)
      assert.equal("http://localhost:3000/api", config.collaboration.api_url)
      assert.equal("test@example.com", config.collaboration.user_id)

      -- Restore original getenv
      os.getenv = original_getenv
    end)

    it("should configure local mode correctly", function()
      local config = package.loaded["screw.config"].get()

      local detection_result = {
        mode = "local",
        reason = "test",
        requires_migration = false,
      }

      local success = ModeDetector.apply_mode(detection_result)

      assert.is_true(success)
      assert.equal("json", config.storage.backend)
      assert.is_false(config.collaboration.enabled)
    end)

    it("should fail when missing API URL for collaborative mode", function()
      -- Mock os.getenv to have user email but no API URL
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_USER_EMAIL" then
          return "test@example.com"
        elseif var == "SCREW_API_URL" then
          return nil -- No API URL
        else
          return original_getenv(var)
        end
      end

      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("SCREW_API_URL.*required", msg)
      end

      local detection_result = {
        mode = "collaborative",
        reason = "test",
        requires_migration = false,
      }

      local success = ModeDetector.apply_mode(detection_result)

      assert.is_false(success)
      assert.is_true(error_called)

      -- Restore original getenv
      os.getenv = original_getenv
    end)

    it("should fail when missing user credentials for collaborative mode", function()
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_API_URL" then
          return "http://localhost:3000/api"
        end
        return nil -- No user credentials
      end

      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("SCREW_USER_EMAIL.*required", msg)
      end

      local detection_result = {
        mode = "collaborative",
        reason = "test",
        requires_migration = false,
      }

      local success = ModeDetector.apply_mode(detection_result)

      assert.is_false(success)
      assert.is_true(error_called)
    end)

    it("should accept SCREW_USER_ID as alternative to email", function()
      -- Mock os.getenv for user ID scenario
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_API_URL" then
          return "http://localhost:3000/api"
        elseif var == "SCREW_USER_ID" then
          return "user123"
        else
          return original_getenv(var)
        end
      end

      local config = package.loaded["screw.config"].get()

      local detection_result = {
        mode = "collaborative",
        reason = "test",
        requires_migration = false,
      }

      local success = ModeDetector.apply_mode(detection_result)

      assert.is_true(success)
      assert.equal("user123", config.collaboration.user_id)

      -- Restore original getenv
      os.getenv = original_getenv
    end)
  end)

  describe("handle_migration", function()
    it("should return true when no migration required", function()
      local detection_result = {
        requires_migration = false,
      }

      local success = ModeDetector.handle_migration(detection_result)

      assert.is_true(success)
    end)

    it("should handle local to database migration", function()
      -- Mock migration utility
      package.loaded["screw.collaboration.migration"] = {
        migrate_local_to_db = function()
          return true
        end,
      }

      local detection_result = {
        requires_migration = true,
        user_choice = "migrate_to_db",
      }

      local success = ModeDetector.handle_migration(detection_result)

      assert.is_true(success)
    end)

    it("should handle database to local export", function()
      package.loaded["screw.collaboration.migration"] = {
        migrate_db_to_local = function()
          return true
        end,
      }

      local detection_result = {
        requires_migration = true,
        user_choice = "export_from_db",
      }

      local success = ModeDetector.handle_migration(detection_result)

      assert.is_true(success)
    end)

    it("should handle migration failure", function()
      package.loaded["screw.collaboration.migration"] = {
        migrate_local_to_db = function()
          return false
        end,
      }

      local detection_result = {
        requires_migration = true,
        user_choice = "migrate_to_db",
      }

      local success = ModeDetector.handle_migration(detection_result)

      assert.is_false(success)
    end)
  end)

  describe("get_status", function()
    it("should return current detection status", function()
      local status = ModeDetector.get_status()

      assert.is_table(status)
      assert.is_boolean(status.local_notes_found)
      assert.is_number(status.local_notes_count)
      assert.is_boolean(status.db_available)
      assert.is_boolean(status.db_notes_found)
      assert.is_number(status.db_notes_count)
    end)
  end)

  describe("force_mode", function()
    it("should force local mode", function()
      local success = ModeDetector.force_mode("local")

      assert.is_true(success)
    end)

    it("should force collaborative mode with proper environment", function()
      -- Mock os.getenv for force mode test
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_API_URL" then
          return "http://localhost:3000/api"
        elseif var == "SCREW_USER_EMAIL" then
          return "test@example.com"
        else
          return original_getenv(var)
        end
      end

      local success = ModeDetector.force_mode("collaborative")

      assert.is_true(success)

      -- Restore original getenv
      os.getenv = original_getenv
    end)

    it("should fail to force collaborative mode without environment", function()
      local success = ModeDetector.force_mode("collaborative")

      assert.is_false(success)
    end)
  end)
end)
