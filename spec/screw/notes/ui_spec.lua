local helpers = require("spec.spec_helper")

describe("screw.notes.ui", function()
  local ui
  local mock_notes
  local mock_utils

  before_each(function()
    helpers.setup_test_env()
    mock_notes = helpers.create_mock_notes(5)

    -- Set up project root for tests
    vim.g.screw_project_root = "/tmp/nvim-test"

    -- Add confirm function to vim.fn for delete confirmation tests
    vim.fn.confirm = function(message, choices, default, type)
      -- Default to "Yes" (choice 1) for tests
      return 1
    end

    -- Mock utils module
    mock_utils = {
      get_author = function()
        return "testuser"
      end,
      info = function(msg)
        -- Store info messages for verification
        _G.test_info_message = msg
      end,
      error = function(msg)
        _G.test_error_message = msg
      end,
    }
    package.loaded["screw.utils"] = mock_utils

    -- Mock notes manager
    package.loaded["screw.notes.manager"] = {
      get_notes = function()
        return mock_notes
      end,
      delete_note = function(id)
        return true
      end,
    }

    -- Mock vim.pesc function
    vim.pesc = function(str)
      return str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
    end

    -- Now require the UI module
    ui = require("screw.notes.ui")
  end)

  after_each(function()
    helpers.cleanup_test_files()
    _G.test_info_message = nil
    _G.test_error_message = nil
  end)

  describe("delete_all_project_notes_with_confirmation", function()
    it("should handle empty project (no notes)", function()
      -- Mock empty notes
      package.loaded["screw.notes.manager"].get_notes = function()
        return {}
      end

      ui.delete_all_project_notes_with_confirmation()

      assert.equal(_G.test_info_message, "No notes found in project")
    end)

    it("should handle case where user has no deletable notes", function()
      -- Create UI module fresh to avoid cached state
      package.loaded["screw.notes.ui"] = nil

      -- Mock notes with different author
      local notes_with_different_author = helpers.create_mock_notes(3)
      for _, note in ipairs(notes_with_different_author) do
        note.author = "otheruser"
      end

      package.loaded["screw.notes.manager"].get_notes = function()
        return notes_with_different_author
      end

      ui = require("screw.notes.ui")
      ui.delete_all_project_notes_with_confirmation()

      assert.equal(
        _G.test_info_message,
        "No notes found in project that you can delete (you can only delete your own notes)"
      )
    end)

    it("should filter notes by author", function()
      -- Reinitialize UI module
      package.loaded["screw.notes.ui"] = nil

      -- Mix of notes with different authors
      local mixed_notes = {
        helpers.create_mock_note({ id = "note-1", author = "testuser" }),
        helpers.create_mock_note({ id = "note-2", author = "otheruser" }),
        helpers.create_mock_note({ id = "note-3", author = "testuser" }),
      }

      package.loaded["screw.notes.manager"].get_notes = function()
        return mixed_notes
      end

      local deleted_count = 0
      package.loaded["screw.notes.manager"].delete_note = function(id)
        deleted_count = deleted_count + 1
        -- Should only delete notes from testuser
        local note_authors = { ["note-1"] = "testuser", ["note-3"] = "testuser" }
        assert.is_not_nil(note_authors[id])
        return true
      end

      ui = require("screw.notes.ui")
      ui.delete_all_project_notes_with_confirmation()

      assert.equal(deleted_count, 2) -- Only 2 notes from testuser should be deleted
      assert.equal(_G.test_info_message, "Successfully deleted 2 note(s) from project")
    end)

    it("should handle deletion failures gracefully", function()
      package.loaded["screw.notes.ui"] = nil

      package.loaded["screw.notes.manager"].delete_note = function(id)
        return false -- Simulate deletion failure
      end

      ui = require("screw.notes.ui")
      ui.delete_all_project_notes_with_confirmation()

      assert.equal(_G.test_error_message, "Failed to delete notes")
    end)

    it("should show confirmation dialog with project path", function()
      package.loaded["screw.notes.ui"] = nil

      local confirmation_message = nil
      vim.fn.confirm = function(message, choices, default, type)
        confirmation_message = message
        return 1 -- Yes
      end

      ui = require("screw.notes.ui")
      ui.delete_all_project_notes_with_confirmation()

      assert.is_not_nil(confirmation_message)
      assert.is_truthy(confirmation_message:match("Project: /tmp/nvim%-test"))
    end)

    it("should respect user cancellation", function()
      vim.fn.confirm = function(message, choices, default, type)
        return 2 -- No
      end

      local delete_called = false
      package.loaded["screw.notes.manager"].delete_note = function(id)
        delete_called = true
        return true
      end

      ui.delete_all_project_notes_with_confirmation()

      assert.is_false(delete_called)
    end)

    it("should handle mixed deletion results", function()
      package.loaded["screw.notes.ui"] = nil

      local call_count = 0
      package.loaded["screw.notes.manager"].delete_note = function(id)
        call_count = call_count + 1
        -- First two deletions succeed, rest fail
        return call_count <= 2
      end

      ui = require("screw.notes.ui")
      ui.delete_all_project_notes_with_confirmation()

      assert.equal(_G.test_info_message, "Successfully deleted 2 note(s) from project")
    end)

    it("should truncate note previews properly", function()
      package.loaded["screw.notes.ui"] = nil

      local long_comment_note = helpers.create_mock_note({
        comment = string.rep("a", 100), -- Long comment that should be truncated
      })

      package.loaded["screw.notes.manager"].get_notes = function()
        return { long_comment_note }
      end

      local confirmation_message = nil
      vim.fn.confirm = function(message, choices, default, type)
        confirmation_message = message
        return 2 -- No, don't actually delete
      end

      ui = require("screw.notes.ui")
      ui.delete_all_project_notes_with_confirmation()

      assert.is_not_nil(confirmation_message)
      -- Should contain "..." indicating truncation
      assert.is_truthy(confirmation_message:match("%.%.%."))
    end)
  end)
end)
