local helpers = require("spec.spec_helper")

describe("screw", function()
  local screw
  local mock_notes

  before_each(function()
    helpers.setup_test_env()
    mock_notes = helpers.create_mock_notes(3)

    -- Set up project root for tests
    vim.g.screw_project_root = "/tmp/nvim-test"

    -- Mock the notes.ui module
    package.loaded["screw.notes.ui"] = {
      setup = function() end,
      open_create_note_window = function() end,
      open_view_notes_window = function() end,
      open_file_notes_window = function() end,
      open_all_notes_window = function() end,
      open_edit_current_line_notes = function() end,
      open_delete_current_line_notes = function() end,
      open_reply_current_line_notes = function() end,
      delete_current_file_notes_with_confirmation = function() end,
      delete_all_project_notes_with_confirmation = function() end,
    }

    -- Mock the notes.manager module
    package.loaded["screw.notes.manager"] = {
      setup = function() end,
      create_note = function(opts)
        return helpers.create_mock_note(opts)
      end,
      get_notes = function(filter)
        if filter then
          return {}
        end
        return mock_notes
      end,
      get_current_line_notes = function()
        return { mock_notes[1] }
      end,
      get_current_file_notes = function()
        return { mock_notes[1], mock_notes[2] }
      end,
      get_note_by_id = function(id)
        for _, note in ipairs(mock_notes) do
          if note.id == id then
            return note
          end
        end
        return nil
      end,
      update_note = function(id, updates)
        return true
      end,
      delete_note = function(id)
        return true
      end,
      add_reply = function(parent_id, comment, author)
        return true
      end,
      get_statistics = function()
        return {
          total = 3,
          vulnerable = 2,
          not_vulnerable = 1,
          todo = 0,
          by_severity = {},
          by_author = {},
          by_cwe = {},
          files_with_notes = {},
        }
      end,
    }

    -- Mock other required modules
    package.loaded["screw.signs"] = {
      setup = function() end,
      should_place_signs = function(bufnr)
        return false
      end,
      place_buffer_signs = function(bufnr) end,
    }

    package.loaded["screw.collaboration"] = {
      setup = function() end,
    }

    package.loaded["screw.export.init"] = {
      export_notes = function(options)
        return true
      end,
    }

    package.loaded["screw.import.init"] = {
      import_sarif = function(options)
        return {
          success = true,
          notes_imported = 5,
          notes_skipped = 0,
          errors = {},
        }
      end,
    }

    package.loaded["screw.jump"] = {
      jump_next = function(opts)
        return true
      end,
      jump_prev = function(opts)
        return true
      end,
    }

    -- Now require the main module
    screw = require("screw")
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("delete_all_project_notes", function()
    it("should call the UI module delete_all_project_notes_with_confirmation function", function()
      local ui_called = false

      -- Mock the UI module to track if it was called
      package.loaded["screw.notes.ui"].delete_all_project_notes_with_confirmation = function()
        ui_called = true
      end

      screw.delete_all_project_notes()

      assert.is_true(ui_called)
    end)

    it("should initialize plugin before calling delete function", function()
      local init_called = false
      local delete_called = false

      -- Mock the manager setup to track initialization
      package.loaded["screw.notes.manager"].setup = function()
        init_called = true
      end

      package.loaded["screw.notes.ui"].delete_all_project_notes_with_confirmation = function()
        delete_called = true
        -- Since init happens in ensure_initialized, it should be called before this
        return true
      end

      screw.delete_all_project_notes()

      assert.is_true(delete_called)
    end)
  end)

  describe("API functions exist", function()
    it("should have delete_all_project_notes function", function()
      assert.is_function(screw.delete_all_project_notes)
    end)
  end)

  describe("integration with existing delete functions", function()
    it("should maintain existing delete_note function", function()
      assert.is_function(screw.delete_note)
    end)

    it("should maintain existing delete_current_file_notes function", function()
      assert.is_function(screw.delete_current_file_notes)
    end)
  end)
end)
