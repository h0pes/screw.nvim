--- Tests for the HTTP collaboration backend
---
--- This test suite validates the HTTP storage backend for collaboration mode,
--- including HTTP API communication, offline caching, and error handling.
---

local helpers = require("spec.spec_helper")

describe("screw.notes.storage.http", function()
  local HttpBackend
  local mock_notes
  local storage_backend
  local original_env = {}

  before_each(function()
    helpers.setup_test_env()

    -- Store original environment
    original_env.SCREW_API_URL = os.getenv("SCREW_API_URL")
    original_env.SCREW_USER_EMAIL = os.getenv("SCREW_USER_EMAIL")
    original_env.SCREW_USER_ID = os.getenv("SCREW_USER_ID")

    -- Mock os.getenv for test environment
    original_env.original_getenv = os.getenv
    os.getenv = function(var)
      if var == "SCREW_API_URL" then
        return "http://localhost:3000/api"
      elseif var == "SCREW_USER_EMAIL" then
        return "test@example.com"
      else
        return original_env.original_getenv(var)
      end
    end

    -- Mock project root
    vim.g.screw_project_root = "/tmp/test-project"

    -- Mock config module
    package.loaded["screw.config"] = {
      get_option = function(option)
        if option == "collaboration" then
          return {
            enabled = true,
            api_url = "http://localhost:3000/api",
            user_id = "test@example.com",
          }
        end
        return {}
      end,
    }

    -- Mock utils functions
    package.loaded["screw.utils"] = {
      get_project_root = function()
        return "/tmp/test-project"
      end,
      deep_copy = function(obj)
        return vim.deepcopy(obj)
      end,
      get_timestamp = function()
        return "2024-01-01T00:00:00Z"
      end,
      generate_id = function()
        return "test-id-" .. math.random(1000, 9999)
      end,
      get_relative_path = function(path)
        -- Always return a relative path (never starting with /)
        if path:match("^/absolute/") then
          return "src/file.lua"
        elseif path:match("^/tmp/test%-project/") then
          return path:gsub("^/tmp/test%-project/", "")
        elseif path:sub(1, 1) == "/" then
          -- For any other absolute path, strip leading / and return relative
          return path:sub(2)
        else
          -- Already relative
          return path
        end
      end,
      get_absolute_path = function(path)
        return "/tmp/test-project/" .. path
      end,
      info = function() end,
      error = function() end,
      warn = function() end,
    }

    -- Create test notes
    mock_notes = helpers.create_mock_notes(3)

    -- Mock vim functions for HTTP requests
    vim.fn.system = function(cmd)
      if cmd[1] == "curl" then
        local endpoint = cmd[#cmd]:match("/api(.*)$")
        if endpoint == "/health" then
          return vim.json.encode({ status = "ok" })
        elseif endpoint:match("^/notes/") then
          if cmd[4] == "GET" then
            return vim.json.encode({ notes = mock_notes or {} })
          elseif cmd[4] == "POST" then
            return vim.json.encode({ note = { id = "new-note-id" } })
          elseif cmd[4] == "PUT" then
            return vim.json.encode({ note = { id = "updated-note-id" } })
          elseif cmd[4] == "DELETE" then
            return vim.json.encode({ success = true })
          end
        elseif endpoint:match("^/stats/") then
          return vim.json.encode({
            total_notes = 42,
            active_users = 3,
            last_activity = "2024-01-01T12:00:00Z",
          })
        end
        return "{}"
      end
      return ""
    end

    vim.v = vim.v or {}
    vim.v.shell_error = 0

    -- Ensure utils is mocked before loading HTTP backend
    -- This is critical because the HTTP backend requires utils immediately

    -- Reset modules in correct order
    package.loaded["screw.notes.storage.http"] = nil

    -- Load HTTP backend AFTER utils is mocked
    HttpBackend = require("screw.notes.storage.http")

    storage_backend = HttpBackend.new({
      backend = "http",
      auto_save = true,
    })
  end)

  after_each(function()
    helpers.cleanup_test_files()

    -- Restore environment
    for key, value in pairs(original_env) do
      if key ~= "original_getenv" then
        vim.env[key] = value
      end
    end

    -- Restore original getenv
    if original_env.original_getenv then
      os.getenv = original_env.original_getenv
    end
  end)

  describe("initialization", function()
    it("should create a new HTTP storage backend", function()
      assert.is_table(storage_backend)
      assert.is_function(storage_backend.setup)
      assert.is_function(storage_backend.connect)
      assert.is_function(storage_backend.save_note)
      assert.is_function(storage_backend.get_all_notes)
    end)

    it("should initialize with default state", function()
      assert.is_false(storage_backend.connected)
      assert.is_table(storage_backend.notes_cache)
      assert.equal("http://localhost:3000/api", storage_backend.api_url)
      assert.equal("test@example.com", storage_backend.user_id)
    end)

    it("should store configuration correctly", function()
      assert.equal("http", storage_backend.config.backend)
      assert.is_true(storage_backend.config.auto_save)
    end)
  end)

  describe("environment configuration", function()
    it("should use SCREW_API_URL environment variable", function()
      assert.equal("http://localhost:3000/api", storage_backend.api_url)
    end)

    it("should handle missing API URL", function()
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_API_URL" then
          return nil
        end
        return original_getenv(var)
      end

      local backend = HttpBackend.new({ backend = "http" })
      assert.equal("http://localhost:3000/api", backend.api_url) -- Default fallback

      os.getenv = original_env.original_getenv
    end)

    it("should prefer SCREW_USER_EMAIL over SCREW_USER_ID", function()
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_USER_EMAIL" then
          return "email@example.com"
        elseif var == "SCREW_USER_ID" then
          return "userid123"
        end
        return original_getenv(var)
      end

      local backend = HttpBackend.new({ backend = "http" })
      assert.equal("email@example.com", backend.user_id)

      os.getenv = original_env.original_getenv
    end)

    it("should fallback to SCREW_USER_ID when email not set", function()
      local original_getenv = os.getenv
      os.getenv = function(var)
        if var == "SCREW_USER_EMAIL" then
          return nil
        elseif var == "SCREW_USER_ID" then
          return "userid123"
        elseif var == "SCREW_API_URL" then
          return "http://localhost:3000/api"
        end
        return original_getenv(var)
      end

      local backend = HttpBackend.new({ backend = "http" })
      assert.equal("userid123", backend.user_id)

      os.getenv = original_env.original_getenv
    end)
  end)

  describe("HTTP API connection", function()
    it("should test API connectivity on connect", function()
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" and cmd[#cmd]:match("/health") then
          return vim.json.encode({ status = "ok" })
        end
        return ""
      end
      vim.v.shell_error = 0

      local success, error_msg = storage_backend:connect()

      assert.is_true(success)
      assert.is_nil(error_msg)
      assert.is_true(storage_backend.connected)
    end)

    it("should handle API connection failure", function()
      vim.fn.system = function()
        return "Connection refused"
      end
      vim.v.shell_error = 1

      local success, error_msg = storage_backend:connect()

      assert.is_false(success)
      assert.matches("Cannot connect to collaboration server", error_msg)
      assert.is_false(storage_backend.connected)
    end)

    it("should handle missing API URL environment variable", function()
      storage_backend.api_url = nil

      local success, error_msg = storage_backend:connect()

      assert.is_false(success)
      assert.equal("SCREW_API_URL environment variable not set", error_msg)
    end)

    it("should handle missing user identification", function()
      storage_backend.user_id = nil

      local success, error_msg = storage_backend:connect()

      assert.is_false(success)
      assert.equal("SCREW_USER_EMAIL or SCREW_USER_ID environment variable not set", error_msg)
    end)

    it("should disconnect properly", function()
      storage_backend.connected = true

      storage_backend:disconnect()

      assert.is_false(storage_backend.connected)
    end)

    it("should report connection status", function()
      storage_backend.connected = true
      assert.is_true(storage_backend:is_connected())

      storage_backend.connected = false
      assert.is_false(storage_backend:is_connected())
    end)
  end)

  describe("setup and initialization", function()
    it("should setup HTTP backend successfully", function()
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" and cmd[#cmd]:match("/health") then
          return vim.json.encode({ status = "ok" })
        elseif cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
          return vim.json.encode({ notes = mock_notes or {} })
        end
        return ""
      end
      vim.v.shell_error = 0

      -- Mock signs module
      package.loaded["screw.signs"] = {
        on_note_added = function() end,
      }

      storage_backend:setup()

      assert.is_true(storage_backend.connected)
      assert.is_table(storage_backend.notes_cache)
    end)

    it("should handle setup failure gracefully", function()
      vim.fn.system = function()
        return "Connection failed"
      end
      vim.v.shell_error = 1

      local warn_called = false
      package.loaded["screw.utils"].warn = function(msg)
        warn_called = true
        assert.matches("HTTP backend setup failed", msg)
      end

      storage_backend:setup()

      assert.is_true(warn_called)
      assert.is_false(storage_backend.connected)
    end)

    it("should load notes and initialize signs on setup", function()
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" and cmd[#cmd]:match("/health") then
          return vim.json.encode({ status = "ok" })
        elseif cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
          return vim.json.encode({ notes = mock_notes })
        end
        return ""
      end
      vim.v.shell_error = 0

      local sign_calls = 0
      package.loaded["screw.signs"] = {
        on_note_added = function()
          sign_calls = sign_calls + 1
        end,
      }

      storage_backend:setup()

      assert.equal(#mock_notes, sign_calls)
    end)
  end)

  describe("note operations", function()
    before_each(function()
      storage_backend.connected = true
      storage_backend.notes_cache = {}

      -- Add test notes to cache
      for _, note in ipairs(mock_notes) do
        table.insert(storage_backend.notes_cache, vim.deepcopy(note))
      end

      -- Default successful HTTP responses
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" then
          local endpoint = cmd[#cmd]:match("/api(.*)$")
          if endpoint and endpoint:match("^/notes/") then
            if cmd[4] == "GET" then
              return vim.json.encode({ notes = mock_notes })
            elseif cmd[4] == "POST" then
              return vim.json.encode({ note = { id = "new-server-id" } })
            elseif cmd[4] == "PUT" then
              return vim.json.encode({ note = { id = "updated-server-id" } })
            elseif cmd[4] == "DELETE" then
              return vim.json.encode({ success = true })
            end
          elseif endpoint and endpoint:match("^/stats/") then
            return vim.json.encode({
              total_notes = 42,
              active_users = 3,
              last_activity = "2024-01-01T12:00:00Z",
            })
          end
        end
        return "{}"
      end
      vim.v.shell_error = 0
    end)

    describe("get_all_notes", function()
      it("should return all notes from server", function()
        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
            return vim.json.encode({ notes = mock_notes })
          end
          return "{}"
        end

        local notes = storage_backend:get_all_notes()

        assert.equal(3, #notes)
        assert.equal(mock_notes[1].id, notes[1].id)
      end)

      it("should return empty array when no notes", function()
        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
            return vim.json.encode({ notes = {} })
          end
          return "{}"
        end

        local notes = storage_backend:get_all_notes()

        assert.equal(0, #notes)
      end)

      it("should refresh cache from server", function()
        local api_called = false
        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
            api_called = true
            return vim.json.encode({ notes = mock_notes })
          end
          return "{}"
        end

        storage_backend:get_all_notes()

        assert.is_true(api_called)
        assert.equal(3, #storage_backend.notes_cache)
      end)
    end)

    describe("get_note", function()
      it("should return specific note by ID from API", function()
        vim.fn.system = function(cmd)
          local url = cmd[#cmd]
          local expected_pattern = "/notes/note/" .. mock_notes[1].id:gsub("%-", "%%-")

          if cmd[1] == "curl" and url:match(expected_pattern .. "$") then
            vim.v.shell_error = 0
            return vim.json.encode({ note = mock_notes[1] })
          end
          vim.v.shell_error = 0
          return "{}"
        end

        local note = storage_backend:get_note(mock_notes[1].id)

        assert.is_table(note)
        assert.equal(mock_notes[1].id, note.id)
        assert.equal(mock_notes[1].comment, note.comment)
      end)

      it("should return nil for nonexistent ID", function()
        vim.fn.system = function()
          return "Not found"
        end
        vim.v.shell_error = 1

        local note = storage_backend:get_note("nonexistent-id")

        assert.is_nil(note)
      end)

      it("should handle API errors gracefully", function()
        vim.fn.system = function()
          return "Server error"
        end
        vim.v.shell_error = 1

        local warn_called = false
        package.loaded["screw.utils"].warn = function(msg)
          warn_called = true
          assert.matches("Failed to get note", msg)
        end

        local note = storage_backend:get_note("some-id")

        assert.is_nil(note)
        assert.is_true(warn_called)
      end)
    end)

    describe("save_note", function()
      it("should save new note via POST API", function()
        -- Test the basic flow step by step
        local new_note = helpers.create_mock_note({ id = "client-id" })

        -- First verify the note is valid
        assert.equal("test.lua", new_note.file_path) -- Should be relative path
        assert.is_true(storage_backend.connected)

        -- Mock HTTP response for POST request and subsequent GET
        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[4] == "POST" and cmd[#cmd]:match("/notes$") then
            vim.v.shell_error = 0
            return vim.json.encode({ note = { id = "server-generated-id" } })
          elseif cmd[1] == "curl" and cmd[4] == "GET" and cmd[#cmd]:match("/notes/test%-project$") then
            -- Return notes that include the saved note with server ID
            local saved_note = helpers.create_mock_note({ id = "server-generated-id" })
            vim.v.shell_error = 0
            return vim.json.encode({ notes = { saved_note } })
          end
          vim.v.shell_error = 0
          return "{}"
        end

        local success = storage_backend:save_note(new_note)

        assert.is_true(success)
        assert.equal("server-generated-id", new_note.id)
      end)

      it("should save existing note via PUT API", function()
        -- Add note to cache first to simulate it came from server
        local existing_note = helpers.create_mock_note({ id = "existing-id" })
        table.insert(storage_backend.notes_cache, existing_note)

        local put_called = false
        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[4] == "PUT" and cmd[#cmd]:match("/notes/existing%-id$") then
            put_called = true
            vim.v.shell_error = 0
            return vim.json.encode({ note = existing_note })
          elseif cmd[1] == "curl" and cmd[4] == "GET" and cmd[#cmd]:match("/notes/test%-project$") then
            vim.v.shell_error = 0
            return vim.json.encode({ notes = {} })
          end
          vim.v.shell_error = 0
          return "{}"
        end
        vim.v.shell_error = 0

        existing_note.comment = "Updated comment"
        local success = storage_backend:save_note(existing_note)

        assert.is_true(success)
        assert.is_true(put_called)
      end)

      it("should handle API save failure", function()
        vim.fn.system = function()
          return "Server error"
        end
        vim.v.shell_error = 1

        local error_called = false
        package.loaded["screw.utils"].error = function(msg)
          error_called = true
          assert.matches("Failed to save note", msg)
        end

        local new_note = helpers.create_mock_note({ id = "fail-save" })
        local success = storage_backend:save_note(new_note)

        assert.is_false(success)
        assert.is_true(error_called)
      end)

      it("should save to cache when offline", function()
        storage_backend.connected = false

        local new_note = helpers.create_mock_note({ id = "offline-note" })
        local success = storage_backend:save_note(new_note)

        assert.is_true(success)
        -- Should find note in cache
        local found = false
        for _, note in ipairs(storage_backend.notes_cache) do
          if note.id == "offline-note" then
            found = true
            break
          end
        end
        assert.is_true(found)
      end)

      it("should normalize file paths to relative", function()
        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[4] == "POST" then
            local data = vim.json.decode(cmd[6]) -- Request body
            assert.not_equal("/", data.file_path:sub(1, 1)) -- Should not start with /
            return vim.json.encode({ note = { id = "new-id" } })
          end
          return "{}"
        end

        local new_note = helpers.create_mock_note({
          id = "path-test",
          file_path = "/absolute/path/to/file.lua",
        })

        storage_backend:save_note(new_note)
      end)
    end)

    describe("delete_note", function()
      it("should delete note via DELETE API", function()
        local delete_called = false
        vim.fn.system = function(cmd)
          if
            cmd[1] == "curl"
            and cmd[4] == "DELETE"
            and cmd[#cmd]:match("/notes/" .. mock_notes[1].id:gsub("%-", "%%-"))
          then
            delete_called = true
            vim.v.shell_error = 0
            return vim.json.encode({ success = true })
          elseif cmd[1] == "curl" and cmd[#cmd]:match("/notes/test%-project$") then
            vim.v.shell_error = 0
            return vim.json.encode({ notes = {} })
          end
          vim.v.shell_error = 0
          return "{}"
        end

        local note_id = mock_notes[1].id
        local success = storage_backend:delete_note(note_id)

        assert.is_true(success)
        assert.is_true(delete_called)
      end)

      it("should handle deletion failure", function()
        vim.fn.system = function()
          return "Delete failed"
        end
        vim.v.shell_error = 1

        local error_called = false
        package.loaded["screw.utils"].error = function(msg)
          error_called = true
          assert.matches("Failed to delete note", msg)
        end

        local note_id = mock_notes[1].id
        local success = storage_backend:delete_note(note_id)

        assert.is_false(success)
        assert.is_true(error_called)
      end)

      it("should remove from cache when offline", function()
        storage_backend.connected = false

        -- Add note to cache first
        local test_note = helpers.create_mock_note({ id = "delete-test" })
        table.insert(storage_backend.notes_cache, test_note)

        local success = storage_backend:delete_note("delete-test")

        assert.is_true(success)
        -- Should not find note in cache
        local found = false
        for _, note in ipairs(storage_backend.notes_cache) do
          if note.id == "delete-test" then
            found = true
            break
          end
        end
        assert.is_false(found)
      end)
    end)

    describe("get_notes_for_file", function()
      it("should return notes for specific file", function()
        storage_backend.notes_cache[1].file_path = "file1.lua"
        storage_backend.notes_cache[2].file_path = "file2.lua"
        storage_backend.notes_cache[3].file_path = "file1.lua"

        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
            return vim.json.encode({ notes = storage_backend.notes_cache })
          end
          return "{}"
        end

        local file_notes = storage_backend:get_notes_for_file("file1.lua")

        assert.equal(2, #file_notes)
        for _, note in ipairs(file_notes) do
          assert.equal("file1.lua", note.file_path)
        end
      end)

      it("should handle absolute file paths", function()
        storage_backend.notes_cache[1].file_path = "src/file1.lua" -- Relative path stored

        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
            return vim.json.encode({ notes = storage_backend.notes_cache })
          end
          return "{}"
        end

        -- Mock utils.get_relative_path
        package.loaded["screw.utils"].get_relative_path = function(path)
          return "src/file1.lua"
        end

        local file_notes = storage_backend:get_notes_for_file("/absolute/path/to/src/file1.lua")

        assert.equal(1, #file_notes)
        assert.equal("src/file1.lua", file_notes[1].file_path)
      end)
    end)

    describe("get_notes_for_line", function()
      it("should return notes for specific file and line", function()
        storage_backend.notes_cache[1].file_path = "test.lua"
        storage_backend.notes_cache[1].line_number = 10
        storage_backend.notes_cache[2].file_path = "test.lua"
        storage_backend.notes_cache[2].line_number = 20

        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
            return vim.json.encode({ notes = storage_backend.notes_cache })
          end
          return "{}"
        end

        local line_notes = storage_backend:get_notes_for_line("test.lua", 10)

        assert.equal(1, #line_notes)
        assert.equal("test.lua", line_notes[1].file_path)
        assert.equal(10, line_notes[1].line_number)
      end)

      it("should handle multiple notes on same line", function()
        storage_backend.notes_cache[1].file_path = "test.lua"
        storage_backend.notes_cache[1].line_number = 10
        storage_backend.notes_cache[2].file_path = "test.lua"
        storage_backend.notes_cache[2].line_number = 10
        storage_backend.notes_cache[3].file_path = "test.lua"
        storage_backend.notes_cache[3].line_number = 20

        vim.fn.system = function(cmd)
          if cmd[1] == "curl" and cmd[#cmd]:match("/notes/") then
            return vim.json.encode({ notes = storage_backend.notes_cache })
          end
          return "{}"
        end

        local line_notes = storage_backend:get_notes_for_line("test.lua", 10)

        assert.equal(2, #line_notes)
        for _, note in ipairs(line_notes) do
          assert.equal("test.lua", note.file_path)
          assert.equal(10, note.line_number)
        end
      end)
    end)
  end)

  describe("HTTP collaboration features", function()
    it("should add replies to notes via API", function()
      -- Ensure the backend is connected
      storage_backend:connect()

      local reply_called = false
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" and cmd[4] == "POST" and cmd[#cmd]:match("/notes/parent%-note%-id/replies") then
          reply_called = true
          vim.v.shell_error = 0
          return vim.json.encode({ reply = { id = "reply-id" } })
        elseif cmd[1] == "curl" and cmd[#cmd]:match("/notes/test%-project$") then
          vim.v.shell_error = 0
          return vim.json.encode({ notes = {} })
        end
        vim.v.shell_error = 0
        return "{}"
      end

      local reply = {
        comment = "Test reply",
        author = "test-user",
        timestamp = "2024-01-01T12:00:00Z",
      }

      local success = storage_backend:add_reply("parent-note-id", reply)

      assert.is_true(success)
      assert.is_true(reply_called)
    end)

    it("should handle reply failure when offline", function()
      storage_backend.connected = false

      local reply = {
        comment = "Test reply",
        author = "test-user",
        timestamp = "2024-01-01T12:00:00Z",
      }

      local success = storage_backend:add_reply("parent-note-id", reply)

      assert.is_false(success)
    end)

    it("should get storage statistics from API", function()
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" and cmd[#cmd]:match("/stats/") then
          return vim.json.encode({
            total_notes = 42,
            active_users = 3,
            last_activity = "2024-01-01T12:00:00Z",
          })
        end
        return "{}"
      end

      local stats = storage_backend:get_storage_stats()

      assert.is_table(stats)
      assert.equal("http", stats.backend_type)
      assert.equal(42, stats.total_notes)
      assert.equal(3, stats.active_users)
    end)

    it("should handle stats API failure gracefully", function()
      vim.fn.system = function()
        return "API Error"
      end
      vim.v.shell_error = 1

      local stats = storage_backend:get_storage_stats()

      assert.is_table(stats)
      assert.equal("http", stats.backend_type)
      assert.equal(0, stats.total_notes)
      assert.is_string(stats.error)
    end)

    it("should clear all notes for project", function()
      -- Ensure the backend is connected
      storage_backend:connect()

      local clear_called = false
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" and cmd[4] == "DELETE" and cmd[#cmd]:match("/notes/test%-project$") then
          clear_called = true
          vim.v.shell_error = 0
          return vim.json.encode({ success = true })
        end
        vim.v.shell_error = 0
        return "{}"
      end

      local success = storage_backend:clear_notes()

      assert.is_true(success)
      assert.is_true(clear_called)
    end)

    it("should replace all notes for project", function()
      -- Ensure the backend is connected
      storage_backend:connect()

      local replace_called = false
      vim.fn.system = function(cmd)
        if cmd[1] == "curl" and cmd[4] == "PUT" and cmd[#cmd]:match("/notes/test%-project/replace$") then
          replace_called = true
          vim.v.shell_error = 0
          return vim.json.encode({ success = true })
        end
        vim.v.shell_error = 0
        return "{}"
      end

      local new_notes = { mock_notes[1] }
      local success = storage_backend:replace_all_notes(new_notes)

      assert.is_true(success)
      assert.is_true(replace_called)
    end)
  end)

  describe("offline mode", function()
    it("should save notes to cache when disconnected", function()
      storage_backend.connected = false
      storage_backend.notes_cache = {}

      local new_note = helpers.create_mock_note({ id = "offline-test" })
      local success = storage_backend:save_note(new_note)

      assert.is_true(success)
      assert.equal(1, #storage_backend.notes_cache)
      assert.equal("offline-test", storage_backend.notes_cache[1].id)
    end)

    it("should update existing notes in cache when offline", function()
      storage_backend.connected = false

      local existing_note = helpers.create_mock_note({ id = "existing", comment = "original" })
      storage_backend.notes_cache = { existing_note }

      existing_note.comment = "updated"
      local success = storage_backend:save_note(existing_note)

      assert.is_true(success)
      assert.equal(1, #storage_backend.notes_cache)
      assert.equal("updated", storage_backend.notes_cache[1].comment)
    end)

    it("should delete notes from cache when offline", function()
      storage_backend.connected = false

      local test_note = helpers.create_mock_note({ id = "delete-offline" })
      storage_backend.notes_cache = { test_note }

      local success = storage_backend:delete_note("delete-offline")

      assert.is_true(success)
      assert.equal(0, #storage_backend.notes_cache)
    end)

    it("should return cached notes when offline", function()
      storage_backend.connected = false
      storage_backend.notes_cache = mock_notes

      local notes = storage_backend:get_all_notes()

      assert.equal(3, #notes)
      assert.equal(mock_notes[1].id, notes[1].id)
    end)

    it("should handle operations that require connectivity", function()
      storage_backend.connected = false

      local success = storage_backend:clear_notes()
      assert.is_false(success)

      success = storage_backend:replace_all_notes({})
      assert.is_false(success)
    end)
  end)

  describe("connection management", function()
    it("should force reconnection", function()
      local disconnect_called = false
      local connect_called = false

      storage_backend.disconnect = function(self)
        disconnect_called = true
        self.connected = false
      end

      storage_backend.connect = function(self)
        connect_called = true
        self.connected = true
        return true, nil
      end

      local success = storage_backend:force_reconnect()

      assert.is_true(success)
      assert.is_true(disconnect_called)
      assert.is_true(connect_called)
    end)

    it("should handle reconnection failure", function()
      storage_backend.connect = function()
        return false, "Connection failed"
      end

      local success = storage_backend:force_reconnect()

      assert.is_false(success)
    end)

    it("should maintain project context across reconnections", function()
      local original_project = storage_backend.project_name
      local original_user = storage_backend.user_id

      storage_backend:force_reconnect()

      assert.equal(original_project, storage_backend.project_name)
      assert.equal(original_user, storage_backend.user_id)
    end)
  end)

  describe("utility functions", function()
    describe("save_notes (batch operation)", function()
      it("should return success for HTTP backend", function()
        -- HTTP backend saves notes individually, so batch save just returns true
        local success = storage_backend:save_notes()

        assert.is_true(success)
      end)
    end)

    describe("force_save", function()
      it("should return success for HTTP backend", function()
        -- HTTP backend saves are immediate, so force save just returns true
        local success = storage_backend:force_save()

        assert.is_true(success)
      end)
    end)

    describe("project name detection", function()
      it("should auto-detect project name from root directory", function()
        assert.is_string(storage_backend.project_name)
        assert.not_equal("", storage_backend.project_name)
      end)
    end)

    describe("HTTP request handling", function()
      it("should handle empty API responses", function()
        vim.fn.system = function()
          return "" -- Empty response
        end
        vim.v.shell_error = 0

        local response, err = storage_backend:http_request("GET", "/test")

        assert.is_table(response)
        assert.is_nil(err)
      end)

      it("should handle invalid JSON responses", function()
        vim.fn.system = function()
          return "invalid json"
        end
        vim.v.shell_error = 0

        local response, err = storage_backend:http_request("GET", "/test")

        assert.is_nil(response)
        assert.matches("Invalid JSON response", err)
      end)

      it("should handle HTTP request failures", function()
        vim.fn.system = function()
          return "curl: connection failed"
        end
        vim.v.shell_error = 1

        local response, err = storage_backend:http_request("GET", "/test")

        assert.is_nil(response)
        assert.matches("HTTP request failed", err)
      end)
    end)
  end)

  describe("error handling", function()
    it("should handle missing curl command gracefully", function()
      vim.fn.system = function()
        return "curl: command not found"
      end
      vim.v.shell_error = 127

      local success, error_msg = storage_backend:connect()

      assert.is_false(success)
      assert.matches("Cannot connect to collaboration server", error_msg)
    end)

    it("should handle malformed API responses", function()
      vim.fn.system = function()
        return "<html>Server Error</html>"
      end
      vim.v.shell_error = 0

      local new_note = helpers.create_mock_note({ id = "malformed-test" })
      local success = storage_backend:save_note(new_note)

      -- Should handle gracefully without crashing
      assert.is_boolean(success)
    end)

    it("should handle API timeouts", function()
      vim.fn.system = function()
        return "curl: (28) Connection timed out"
      end
      vim.v.shell_error = 28

      local success, error_msg = storage_backend:connect()

      assert.is_false(success)
      assert.matches("Cannot connect to collaboration server", error_msg)
    end)

    it("should handle network connectivity issues", function()
      vim.fn.system = function()
        return "curl: (6) Could not resolve host"
      end
      vim.v.shell_error = 6

      local success, error_msg = storage_backend:connect()

      assert.is_false(success)
      assert.matches("Cannot connect to collaboration server", error_msg)
    end)

    it("should handle server errors gracefully", function()
      vim.fn.system = function()
        return vim.json.encode({ error = "Internal server error" })
      end
      vim.v.shell_error = 0

      local new_note = helpers.create_mock_note({ id = "server-error-test" })
      local success = storage_backend:save_note(new_note)

      -- Should handle gracefully
      assert.is_boolean(success)
    end)
  end)
end)
