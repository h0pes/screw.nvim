--- Tests for the JSON storage backend
---
--- This test suite validates the JSON file storage implementation,
--- including file I/O, note persistence, and error handling.
---

local helpers = require("spec.spec_helper")

describe("screw.notes.storage.json", function()
  local JsonStorage
  local mock_notes
  local storage_backend

  before_each(function()
    helpers.setup_test_env()

    -- Mock project root
    vim.g.screw_project_root = "/tmp/test-project"

    -- Mock utils functions
    package.loaded["screw.utils"] = {
      get_project_root = function()
        return "/tmp/test-project"
      end,
      ensure_dir = function()
        return true
      end,
      file_exists = function(path)
        -- Default to false, tests can override
        return false
      end,
      read_file = function()
        -- Default to no file, tests can override
        return nil
      end,
      write_file = function()
        -- Default to success, tests can override
        return true
      end,
      deep_copy = function(obj)
        return vim.deepcopy(obj)
      end,
      get_timestamp = function()
        return "2024-01-01T00:00:00Z"
      end,
      info = function() end,
      error = function() end,
    }

    -- Mock file system operations
    vim.fn.glob = function()
      return {} -- Default to no files
    end

    vim.loop.fs_stat = function()
      return { mtime = { sec = 1640995200 } } -- Default timestamp
    end

    -- Create test notes
    mock_notes = helpers.create_mock_notes(3)

    -- Reset module and create new instance
    package.loaded["screw.notes.storage.json"] = nil
    JsonStorage = require("screw.notes.storage.json")

    storage_backend = JsonStorage.new({
      auto_save = true,
      filename = "test_notes.json",
    })
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("initialization", function()
    it("should create a new JSON storage backend", function()
      assert.is_table(storage_backend)
      assert.is_function(storage_backend.setup)
      assert.is_function(storage_backend.save_note)
      assert.is_function(storage_backend.get_all_notes)
    end)

    it("should setup with default configuration", function()
      local backend = JsonStorage.new({})

      assert.is_table(backend)
      assert.is_table(backend.config)
    end)
  end)

  describe("storage path resolution", function()
    it("should use configured filename", function()
      local path = storage_backend:get_storage_path()

      assert.equal("/tmp/test-project/test_notes.json", path)
    end)

    it("should find existing notes file when no filename specified", function()
      vim.fn.glob = function(pattern)
        if pattern:match("screw_notes_.*.json") then
          return { "/tmp/test-project/screw_notes_existing.json" }
        end
        return {}
      end

      local backend = JsonStorage.new({ auto_save = false })
      local path = backend:get_storage_path()

      assert.equal("/tmp/test-project/screw_notes_existing.json", path)
    end)

    it("should create timestamped filename when no files exist", function()
      local backend = JsonStorage.new({ auto_save = false })
      local path = backend:get_storage_path()

      assert.matches("/tmp/test%-project/screw_notes_%d+_%d+%.json", path)
    end)

    it("should choose most recently modified file", function()
      vim.fn.glob = function()
        return {
          "/tmp/test-project/screw_notes_old.json",
          "/tmp/test-project/screw_notes_new.json",
        }
      end

      vim.loop.fs_stat = function(path)
        if path:match("new") then
          return { mtime = { sec = 1640995300 } } -- Newer
        else
          return { mtime = { sec = 1640995200 } } -- Older
        end
      end

      local backend = JsonStorage.new({ auto_save = false })
      local path = backend:get_storage_path()

      assert.equal("/tmp/test-project/screw_notes_new.json", path)
    end)

    it("should cache storage path", function()
      local path1 = storage_backend:get_storage_path()
      local path2 = storage_backend:get_storage_path()

      assert.equal(path1, path2)
    end)
  end)

  describe("note loading", function()
    it("should load notes from existing file", function()
      local test_data = {
        version = "1.0",
        notes = mock_notes,
        metadata = { total_notes = 3 },
      }

      package.loaded["screw.utils"].file_exists = function()
        return true
      end

      package.loaded["screw.utils"].read_file = function()
        return vim.json.encode(test_data)
      end

      storage_backend:load_notes()
      local loaded_notes = storage_backend:get_all_notes()

      assert.equal(3, #loaded_notes)
      assert.equal(mock_notes[1].id, loaded_notes[1].id)
    end)

    it("should handle missing file gracefully", function()
      package.loaded["screw.utils"].file_exists = function()
        return false
      end

      storage_backend:load_notes()
      local notes = storage_backend:get_all_notes()

      assert.equal(0, #notes)
    end)

    it("should handle file read errors", function()
      package.loaded["screw.utils"].file_exists = function()
        return true
      end

      package.loaded["screw.utils"].read_file = function()
        return nil -- Read failure
      end

      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("Failed to read notes file", msg)
      end

      storage_backend:load_notes()

      assert.is_true(error_called)
    end)

    it("should handle JSON parse errors", function()
      package.loaded["screw.utils"].file_exists = function()
        return true
      end

      package.loaded["screw.utils"].read_file = function()
        return "invalid json content"
      end

      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("Failed to parse notes file", msg)
      end

      storage_backend:load_notes()

      assert.is_true(error_called)
    end)

    it("should handle malformed note data", function()
      package.loaded["screw.utils"].file_exists = function()
        return true
      end

      package.loaded["screw.utils"].read_file = function()
        return '{"invalid": "structure"}'
      end

      storage_backend:load_notes()
      local notes = storage_backend:get_all_notes()

      assert.equal(0, #notes)
    end)
  end)

  describe("note saving", function()
    it("should save notes to file", function()
      local write_called = false
      local written_content = nil

      package.loaded["screw.utils"].write_file = function(path, content)
        write_called = true
        written_content = content
        return true
      end

      storage_backend.notes = mock_notes
      local success = storage_backend:save_notes()

      assert.is_true(success)
      assert.is_true(write_called)
      assert.is_string(written_content)

      local decoded = vim.json.decode(written_content)
      assert.equal("1.0", decoded.version)
      assert.equal(3, #decoded.notes)
      assert.equal(3, decoded.metadata.total_notes)
    end)

    it("should handle JSON encoding errors", function()
      storage_backend.notes = { { invalid = function() end } } -- Function can't be encoded

      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("Failed to encode notes", msg)
      end

      local success = storage_backend:save_notes()

      assert.is_false(success)
      assert.is_true(error_called)
    end)

    it("should handle file write errors", function()
      package.loaded["screw.utils"].write_file = function()
        return false -- Write failure
      end

      local error_called = false
      package.loaded["screw.utils"].error = function(msg)
        error_called = true
        assert.matches("Failed to write notes file", msg)
      end

      storage_backend.notes = mock_notes
      local success = storage_backend:save_notes()

      assert.is_false(success)
      assert.is_true(error_called)
    end)
  end)

  describe("note operations", function()
    before_each(function()
      storage_backend.notes = vim.deepcopy(mock_notes)
    end)

    describe("get_all_notes", function()
      it("should return all notes", function()
        local notes = storage_backend:get_all_notes()

        assert.equal(3, #notes)
        assert.equal(mock_notes[1].id, notes[1].id)
      end)
    end)

    describe("get_note", function()
      it("should return specific note by ID", function()
        local note = storage_backend:get_note(mock_notes[1].id)

        assert.is_table(note)
        assert.equal(mock_notes[1].id, note.id)
        assert.equal(mock_notes[1].comment, note.comment)
      end)

      it("should return nil for nonexistent ID", function()
        local note = storage_backend:get_note("nonexistent-id")

        assert.is_nil(note)
      end)

      it("should return a deep copy", function()
        local note = storage_backend:get_note(mock_notes[1].id)
        note.comment = "modified"

        local original = storage_backend:get_note(mock_notes[1].id)
        assert.not_equal("modified", original.comment)
      end)
    end)

    describe("save_note", function()
      it("should add new note", function()
        local new_note = helpers.create_mock_note({ id = "new-note" })

        local success = storage_backend:save_note(new_note)

        assert.is_true(success)
        assert.equal(4, #storage_backend.notes)

        local saved_note = storage_backend:get_note("new-note")
        assert.is_table(saved_note)
        assert.equal(new_note.comment, saved_note.comment)
      end)

      it("should update existing note", function()
        local updated_note = vim.deepcopy(mock_notes[1])
        updated_note.comment = "Updated comment"

        local success = storage_backend:save_note(updated_note)

        assert.is_true(success)
        assert.equal(3, #storage_backend.notes) -- No new note added

        local saved_note = storage_backend:get_note(mock_notes[1].id)
        assert.equal("Updated comment", saved_note.comment)
      end)

      it("should auto-save when configured", function()
        local save_called = false
        storage_backend.save_notes = function()
          save_called = true
          return true
        end

        storage_backend.config.auto_save = true
        local new_note = helpers.create_mock_note({ id = "auto-save-test" })

        storage_backend:save_note(new_note)

        assert.is_true(save_called)
      end)

      it("should not auto-save when disabled", function()
        local save_called = false
        storage_backend.save_notes = function()
          save_called = true
          return true
        end

        storage_backend.config.auto_save = false
        local new_note = helpers.create_mock_note({ id = "no-auto-save" })

        storage_backend:save_note(new_note)

        assert.is_false(save_called)
      end)

      it("should reject note without ID", function()
        local invalid_note = { comment = "No ID" }

        local success = storage_backend:save_note(invalid_note)

        assert.is_false(success)
      end)

      it("should reject nil note", function()
        local success = storage_backend:save_note(nil)

        assert.is_false(success)
      end)
    end)

    describe("delete_note", function()
      it("should delete existing note", function()
        local note_id = mock_notes[2].id

        local success = storage_backend:delete_note(note_id)

        assert.is_true(success)
        assert.equal(2, #storage_backend.notes)
        assert.is_nil(storage_backend:get_note(note_id))
      end)

      it("should return false for nonexistent note", function()
        local success = storage_backend:delete_note("nonexistent-id")

        assert.is_false(success)
        assert.equal(3, #storage_backend.notes) -- No notes removed
      end)

      it("should auto-save when configured", function()
        local save_called = false
        storage_backend.save_notes = function()
          save_called = true
          return true
        end

        storage_backend.config.auto_save = true

        storage_backend:delete_note(mock_notes[1].id)

        assert.is_true(save_called)
      end)
    end)

    describe("get_notes_for_file", function()
      it("should return notes for specific file", function()
        -- Set up notes with different file paths
        storage_backend.notes[1].file_path = "file1.lua"
        storage_backend.notes[2].file_path = "file2.lua"
        storage_backend.notes[3].file_path = "file1.lua"

        local file_notes = storage_backend:get_notes_for_file("file1.lua")

        assert.equal(2, #file_notes)
        assert.equal("file1.lua", file_notes[1].file_path)
        assert.equal("file1.lua", file_notes[2].file_path)
      end)

      it("should return empty array for file with no notes", function()
        local file_notes = storage_backend:get_notes_for_file("nonexistent.lua")

        assert.equal(0, #file_notes)
      end)

      it("should return deep copies", function()
        storage_backend.notes[1].file_path = "test.lua"

        local file_notes = storage_backend:get_notes_for_file("test.lua")
        file_notes[1].comment = "modified"

        local original = storage_backend:get_note(storage_backend.notes[1].id)
        assert.not_equal("modified", original.comment)
      end)
    end)

    describe("get_notes_for_line", function()
      it("should return notes for specific file and line", function()
        storage_backend.notes[1].file_path = "test.lua"
        storage_backend.notes[1].line_number = 10
        storage_backend.notes[2].file_path = "test.lua"
        storage_backend.notes[2].line_number = 20
        storage_backend.notes[3].file_path = "test.lua"
        storage_backend.notes[3].line_number = 10

        local line_notes = storage_backend:get_notes_for_line("test.lua", 10)

        assert.equal(2, #line_notes)
        for _, note in ipairs(line_notes) do
          assert.equal("test.lua", note.file_path)
          assert.equal(10, note.line_number)
        end
      end)

      it("should return empty array for line with no notes", function()
        local line_notes = storage_backend:get_notes_for_line("test.lua", 999)

        assert.equal(0, #line_notes)
      end)
    end)
  end)

  describe("utility functions", function()
    describe("clear_notes", function()
      it("should remove all notes", function()
        storage_backend.notes = vim.deepcopy(mock_notes)

        storage_backend:clear_notes()

        assert.equal(0, #storage_backend.notes)
      end)
    end)

    describe("force_save", function()
      it("should trigger save_notes", function()
        local save_called = false
        storage_backend.save_notes = function()
          save_called = true
          return true
        end

        local success = storage_backend:force_save()

        assert.is_true(success)
        assert.is_true(save_called)
      end)
    end)

    describe("get_storage_stats", function()
      it("should return storage statistics", function()
        storage_backend.notes = mock_notes

        local stats = storage_backend:get_storage_stats()

        assert.is_table(stats)
        assert.equal(3, stats.total_notes)
        assert.equal("json", stats.backend_type)
        assert.is_string(stats.storage_path)
        assert.is_boolean(stats.file_exists)
        assert.is_boolean(stats.auto_save)
      end)

      it("should include file size when file exists", function()
        package.loaded["screw.utils"].file_exists = function()
          return true
        end

        package.loaded["screw.utils"].read_file = function()
          return "test content"
        end

        local stats = storage_backend:get_storage_stats()

        assert.equal(12, stats.file_size) -- Length of "test content"
      end)
    end)

    describe("replace_all_notes", function()
      it("should replace all notes with new set", function()
        storage_backend.notes = mock_notes

        local new_notes = { helpers.create_mock_note({ id = "replacement" }) }
        local success = storage_backend:replace_all_notes(new_notes)

        assert.is_true(success)
        assert.equal(1, #storage_backend.notes)
        assert.equal("replacement", storage_backend.notes[1].id)
      end)

      it("should handle empty replacement", function()
        storage_backend.notes = mock_notes

        local success = storage_backend:replace_all_notes({})

        assert.is_true(success)
        assert.equal(0, #storage_backend.notes)
      end)

      it("should handle nil replacement", function()
        storage_backend.notes = mock_notes

        local success = storage_backend:replace_all_notes(nil)

        assert.is_true(success)
        assert.equal(0, #storage_backend.notes)
      end)

      it("should auto-save when configured", function()
        local save_called = false
        storage_backend.save_notes = function()
          save_called = true
          return true
        end

        storage_backend.config.auto_save = true

        storage_backend:replace_all_notes({})

        assert.is_true(save_called)
      end)
    end)
  end)

  describe("integration", function()
    it("should handle complete workflow", function()
      -- Start with empty storage
      storage_backend:setup()
      assert.equal(0, #storage_backend:get_all_notes())

      -- Add some notes
      local note1 = helpers.create_mock_note({ id = "workflow-1" })
      local note2 = helpers.create_mock_note({ id = "workflow-2" })

      storage_backend:save_note(note1)
      storage_backend:save_note(note2)

      assert.equal(2, #storage_backend:get_all_notes())

      -- Update a note
      note1.comment = "Updated comment"
      storage_backend:save_note(note1)

      local updated = storage_backend:get_note("workflow-1")
      assert.equal("Updated comment", updated.comment)

      -- Delete a note
      storage_backend:delete_note("workflow-2")
      assert.equal(1, #storage_backend:get_all_notes())
      assert.is_nil(storage_backend:get_note("workflow-2"))
    end)
  end)
end)
