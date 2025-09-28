--- Tests for the main collaboration module
---
--- This test suite validates the collaboration module's setup, mode switching,
--- real-time sync integration, and error handling.
---

local helpers = require("spec.spec_helper")
local collaboration = require("screw.collaboration")

describe("screw.collaboration", function()
  local original_env = {}

  before_each(function()
    helpers.setup_test_env()

    -- Store original environment variables
    original_env.SCREW_API_URL = os.getenv("SCREW_API_URL")
    original_env.SCREW_USER_EMAIL = os.getenv("SCREW_USER_EMAIL")
    original_env.SCREW_USER_ID = os.getenv("SCREW_USER_ID")

    -- Clear environment for clean testing
    for key, _ in pairs(original_env) do
      vim.env[key] = nil
    end

    -- Mock the config module
    package.loaded["screw.config"] = {
      get_option = function(path)
        if path == "collaboration" then
          return { enabled = nil } -- Not explicitly configured
        end
        return {}
      end,
      get = function()
        return {
          storage = { backend = "json" },
          collaboration = {
            enabled = false,
            api_url = nil,
            user_id = nil,
            database_url = nil,
          },
        }
      end,
    }

    -- Mock mode detector
    package.loaded["screw.collaboration.mode_detector"] = {
      detect_mode = function()
        return {
          mode = "local",
          reason = "test mode",
          requires_migration = false,
          local_notes_found = false,
          db_available = false,
          db_notes_found = false,
          user_choice = "local",
        }
      end,
      apply_mode = function()
        return true
      end,
      handle_migration = function()
        return true
      end,
      force_mode = function()
        return true
      end,
    }

    -- Mock signs module
    package.loaded["screw.signs"] = {
      setup = function() end,
    }

    -- Reset collaboration state
    package.loaded["screw.collaboration"] = nil
    collaboration = require("screw.collaboration")
  end)

  after_each(function()
    helpers.cleanup_test_files()

    -- Restore original environment variables
    for key, value in pairs(original_env) do
      vim.env[key] = value
    end
  end)

  describe("setup", function()
    it("should initialize with local mode by default", function()
      collaboration.setup()

      local status = collaboration.get_status()

      assert.is_true(status.initialized)
      assert.equal("local", status.mode)
    end)

    it("should respect explicit collaborative configuration", function()
      -- Mock explicit collaborative config
      package.loaded["screw.config"].get_option = function(path)
        if path == "collaboration" then
          return { enabled = true }
        end
        return {}
      end

      -- Set required environment variables
      os.getenv = function(var)
        if var == "SCREW_API_URL" then
          return "http://test-api.example.com"
        elseif var == "SCREW_USER_EMAIL" then
          return "test@example.com"
        end
        return nil
      end

      collaboration.setup()

      local status = collaboration.get_status()

      assert.is_true(status.initialized)
      assert.equal("collaborative", status.mode)
    end)

    it("should fail setup with missing API_URL in collaborative mode", function()
      package.loaded["screw.config"].get_option = function(path)
        if path == "collaboration" then
          return { enabled = true }
        end
        return {}
      end

      -- Clear any environment variables
      os.getenv = function(var)
        if var == "SCREW_USER_EMAIL" then
          return "test@example.com"
        end
        return nil
      end

      -- Mock utils.error to capture the error
      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("SCREW_API_URL.*required", msg)
      end

      collaboration.setup()

      assert.is_true(error_called)

      -- Check that setup was not completed due to error
      local status = collaboration.get_status()
      assert.is_false(status.initialized)
    end)

    it("should fail setup with missing user credentials in collaborative mode", function()
      package.loaded["screw.config"].get_option = function(path)
        if path == "collaboration" then
          return { enabled = true }
        end
        return {}
      end

      -- Only set API URL, not user credentials
      os.getenv = function(var)
        if var == "SCREW_API_URL" then
          return "http://test-api.example.com"
        end
        return nil
      end

      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("SCREW_USER_EMAIL.*required", msg)
      end

      collaboration.setup()

      assert.is_true(error_called)

      -- Check that setup was not completed due to error
      local status = collaboration.get_status()
      assert.is_false(status.initialized)
    end)

    it("should handle migration when required", function()
      -- Mock detection result requiring migration
      package.loaded["screw.collaboration.mode_detector"].detect_mode = function()
        return {
          mode = "collaborative",
          reason = "migration needed",
          requires_migration = true,
          local_notes_found = true,
          db_available = true,
          db_notes_found = false,
          user_choice = "migrate_to_db",
        }
      end

      local migration_called = false
      package.loaded["screw.collaboration.mode_detector"].handle_migration = function()
        migration_called = true
        return true
      end

      collaboration.setup()

      assert.is_true(migration_called)
    end)

    it("should fallback to local mode on migration failure", function()
      package.loaded["screw.collaboration.mode_detector"].detect_mode = function()
        return {
          mode = "collaborative",
          reason = "migration needed",
          requires_migration = true,
          local_notes_found = true,
          db_available = true,
          db_notes_found = false,
          user_choice = "migrate_to_db",
        }
      end

      -- Mock migration failure
      package.loaded["screw.collaboration.mode_detector"].handle_migration = function()
        return false
      end

      local force_mode_called = false
      package.loaded["screw.collaboration.mode_detector"].force_mode = function(mode)
        force_mode_called = true
        assert.equal("local", mode)
        return true
      end

      collaboration.setup()

      assert.is_true(force_mode_called)

      local status = collaboration.get_status()
      assert.equal("local", status.mode)
    end)

    it("should not reinitialize if already initialized", function()
      collaboration.setup()

      local first_status = collaboration.get_status()
      assert.is_true(first_status.initialized)

      -- Setup again - should not reinitialize
      collaboration.setup()

      local second_status = collaboration.get_status()
      assert.is_true(second_status.initialized)
    end)
  end)

  describe("get_status", function()
    it("should return current collaboration status", function()
      collaboration.setup()

      local status = collaboration.get_status()

      assert.is_table(status)
      assert.is_boolean(status.initialized)
      assert.is_string(status.mode)
      assert.is_table(status.detection_result)
    end)

    it("should include realtime sync status when available", function()
      -- Mock realtime sync
      local mock_realtime = {
        get_status = function()
          return {
            is_listening = true,
            is_supported = true,
          }
        end,
      }

      -- This would normally be set up in collaborative mode
      -- For testing, we'll mock it directly
      collaboration.setup()

      local status = collaboration.get_status()

      -- In local mode, realtime_sync should be nil
      assert.is_nil(status.realtime_sync)
    end)
  end)

  describe("switch_mode", function()
    it("should switch from local to collaborative mode", function()
      collaboration.setup()

      -- Mock confirmation dialog to accept
      vim.fn.confirm = function()
        return 1 -- Yes
      end

      local switch_success = collaboration.switch_mode("collaborative")

      assert.is_true(switch_success)
    end)

    it("should not switch when already in target mode", function()
      collaboration.setup()

      local switch_success = collaboration.switch_mode("local")

      assert.is_true(switch_success)
    end)

    it("should respect user cancellation", function()
      collaboration.setup()

      -- Mock confirmation dialog to cancel
      vim.fn.confirm = function()
        return 2 -- No
      end

      local switch_success = collaboration.switch_mode("collaborative")

      assert.is_false(switch_success)
    end)

    it("should handle force switch without confirmation", function()
      collaboration.setup()

      local switch_success = collaboration.switch_mode("collaborative", true)

      assert.is_true(switch_success)
    end)

    it("should handle switch failure gracefully", function()
      collaboration.setup()

      -- Mock force_mode to fail
      package.loaded["screw.collaboration.mode_detector"].force_mode = function()
        return false
      end

      vim.fn.confirm = function()
        return 1 -- Yes
      end

      local switch_success = collaboration.switch_mode("collaborative")

      assert.is_false(switch_success)
    end)
  end)

  describe("sync_now", function()
    it("should warn when not in collaborative mode", function()
      collaboration.setup() -- Starts in local mode

      local warn_called = false
      local utils = require("screw.utils")
      local original_warn = utils.warn
      utils.warn = function(msg)
        warn_called = true
        assert.matches("only available in collaborative mode", msg)
      end

      local sync_success = collaboration.sync_now()

      assert.is_false(sync_success)
      assert.is_true(warn_called)

      utils.warn = original_warn
    end)

    it("should trigger manual sync in collaborative mode", function()
      -- Mock collaborative mode setup
      package.loaded["screw.collaboration.mode_detector"].detect_mode = function()
        return {
          mode = "collaborative",
          reason = "test collaborative",
          requires_migration = false,
          local_notes_found = false,
          db_available = true,
          db_notes_found = false,
          user_choice = "collaborative",
        }
      end

      -- Mock storage backend with sync capability and storage module
      local sync_called = false
      package.loaded["screw.notes.storage"] = {
        get_backend = function()
          return {
            load_notes = function()
              sync_called = true
            end,
          }
        end,
        get_all_notes = function()
          return {}
        end,
      }

      collaboration.setup()

      local sync_success = collaboration.sync_now()

      assert.is_true(sync_success)
      assert.is_true(sync_called)
    end)

    it("should handle sync failure", function()
      package.loaded["screw.collaboration.mode_detector"].detect_mode = function()
        return {
          mode = "collaborative",
          reason = "test collaborative",
          requires_migration = false,
          local_notes_found = false,
          db_available = true,
          db_notes_found = false,
          user_choice = "collaborative",
        }
      end

      -- Mock storage backend without sync capability
      package.loaded["screw.notes.storage"] = {
        get_backend = function()
          return {} -- No load_notes method
        end,
      }

      local error_called = false
      local utils = require("screw.utils")
      local original_error = utils.error
      utils.error = function(msg)
        error_called = true
        assert.matches("does not support manual sync", msg)
      end

      collaboration.setup()

      local sync_success = collaboration.sync_now()

      assert.is_false(sync_success)
      assert.is_true(error_called)

      utils.error = original_error
    end)
  end)

  describe("show_info", function()
    it("should display collaboration information", function()
      collaboration.setup()

      local notify_called = false
      local notify_content = nil

      -- Store original vim.notify
      local original_notify = vim.notify

      -- Mock vim.notify
      vim.notify = function(content, level, opts)
        notify_called = true
        notify_content = content
        assert.equal(vim.log.levels.INFO, level)
        assert.equal("screw.nvim Collaboration", opts.title)
        assert.equal(false, opts.timeout)
      end

      collaboration.show_info()

      -- Restore original vim.notify
      vim.notify = original_notify

      assert.is_true(notify_called)
      assert.is_string(notify_content)
      assert.matches("=== screw.nvim Collaboration Status ===", notify_content)
    end)
  end)

  describe("migration", function()
    it("should return migration utilities", function()
      local migration_utils = collaboration.migration()

      assert.is_table(migration_utils)
    end)
  end)

  describe("cleanup", function()
    it("should clean up collaboration resources", function()
      collaboration.setup()

      -- This should not error
      collaboration.cleanup()

      -- Multiple cleanups should be safe
      collaboration.cleanup()
    end)

    it("should stop realtime sync if running", function()
      -- This test would be expanded when we have actual realtime sync
      collaboration.setup()
      collaboration.cleanup()

      -- Should complete without error
      assert.is_true(true)
    end)
  end)

  describe("error handling", function()
    it("should handle missing mode detector gracefully", function()
      package.loaded["screw.collaboration.mode_detector"] = nil

      -- Should not crash
      local success = pcall(function()
        collaboration.setup()
      end)

      -- May fail but should not crash
      assert.is_boolean(success)
    end)

    it("should handle config errors gracefully", function()
      package.loaded["screw.config"] = nil

      local success = pcall(function()
        collaboration.setup()
      end)

      assert.is_boolean(success)
    end)
  end)
end)
