local helpers = require("spec.spec_helper")

describe("screw.notes.manager", function()
  local manager
  local mock_note

  before_each(function()
    helpers.setup_test_env()
    manager = require("screw.notes.manager")
    mock_note = helpers.create_mock_note()

    -- Mock storage
    package.loaded["screw.notes.storage"] = {
      setup = function() end,
      save_note = function()
        return true
      end,
      get_all_notes = function()
        return { mock_note }
      end,
      get_note = function()
        return mock_note
      end,
      delete_note = function()
        return true
      end,
      get_notes_for_file = function()
        return { mock_note }
      end,
      get_notes_for_line = function()
        return { mock_note }
      end,
    }
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("create_note", function()
    it("should create a note with valid data", function()
      local opts = {
        comment = "Test security issue",
        state = "vulnerable",
        severity = "high",
        cwe = "CWE-79",
      }

      local note = manager.create_note(opts)

      assert.is_table(note)
      assert.equal(note.comment, opts.comment)
      assert.equal(note.state, opts.state)
      assert.equal(note.severity, opts.severity)
      assert.equal(note.cwe, opts.cwe)
    end)

    it("should reject note without comment", function()
      local opts = {
        state = "vulnerable",
        severity = "high",
      }

      local note = manager.create_note(opts)

      assert.is_nil(note)
    end)

    it("should reject vulnerable note without severity", function()
      local opts = {
        comment = "Test issue",
        state = "vulnerable",
      }

      local note = manager.create_note(opts)

      assert.is_nil(note)
    end)

    it("should reject invalid CWE format", function()
      local opts = {
        comment = "Test issue",
        state = "vulnerable",
        severity = "high",
        cwe = "invalid-cwe",
      }

      local note = manager.create_note(opts)

      assert.is_nil(note)
    end)

    it("should reject invalid state", function()
      local opts = {
        comment = "Test issue",
        state = "invalid",
      }

      local note = manager.create_note(opts)

      assert.is_nil(note)
    end)
  end)

  describe("get_notes", function()
    it("should return all notes when no filter", function()
      local notes = manager.get_notes()

      assert.is_table(notes)
      assert.equal(#notes, 1)
    end)

    it("should filter notes by state", function()
      local filter = { state = "vulnerable" }
      local notes = manager.get_notes(filter)

      assert.is_table(notes)
      -- Should contain our mock note which is vulnerable
      assert.equal(#notes, 1)
    end)

    it("should filter notes by author", function()
      local filter = { author = "testuser" }
      local notes = manager.get_notes(filter)

      assert.is_table(notes)
      assert.equal(#notes, 1)
    end)

    it("should filter notes by CWE", function()
      local filter = { cwe = "CWE-79" }
      local notes = manager.get_notes(filter)

      assert.is_table(notes)
      assert.equal(#notes, 1)
    end)

    it("should return empty when filter doesn't match", function()
      local filter = { state = "not_vulnerable" }
      local notes = manager.get_notes(filter)

      assert.is_table(notes)
      assert.equal(#notes, 0)
    end)
  end)

  describe("get_current_file_notes", function()
    it("should return notes for current file", function()
      local notes = manager.get_current_file_notes()

      assert.is_table(notes)
    end)
  end)

  describe("get_current_line_notes", function()
    it("should return notes for current line", function()
      local notes = manager.get_current_line_notes()

      assert.is_table(notes)
    end)
  end)

  describe("get_note_by_id", function()
    it("should return note by ID", function()
      local note = manager.get_note_by_id("test-note-123")

      assert.is_table(note)
      assert.equal(note.id, "test-note-123")
    end)
  end)

  describe("update_note", function()
    it("should update existing note", function()
      local updates = {
        comment = "Updated comment",
        state = "not_vulnerable",
      }

      local result = manager.update_note("test-note-123", updates)

      assert.is_true(result)
    end)

    it("should reject update with invalid CWE", function()
      local updates = {
        cwe = "invalid-cwe",
      }

      local result = manager.update_note("test-note-123", updates)

      assert.is_false(result)
    end)

    it("should reject update with invalid state", function()
      local updates = {
        state = "invalid",
      }

      local result = manager.update_note("test-note-123", updates)

      assert.is_false(result)
    end)
  end)

  describe("delete_note", function()
    it("should delete existing note", function()
      local result = manager.delete_note("test-note-123")

      assert.is_true(result)
    end)
  end)

  describe("add_reply", function()
    it("should add reply to existing note", function()
      local result = manager.add_reply("test-note-123", "This is a reply")

      assert.is_true(result)
    end)

    it("should reject empty reply", function()
      local result = manager.add_reply("test-note-123", "")

      assert.is_false(result)
    end)
  end)

  describe("get_statistics", function()
    it("should return statistics about notes", function()
      local stats = manager.get_statistics()

      assert.is_table(stats)
      assert.is_number(stats.total)
      assert.is_number(stats.vulnerable)
      assert.is_number(stats.not_vulnerable)
      assert.is_number(stats.todo)
      assert.is_table(stats.by_severity)
      assert.is_table(stats.by_author)
      assert.is_table(stats.by_cwe)
      assert.is_table(stats.files_with_notes)
    end)
  end)
end)
