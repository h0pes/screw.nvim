--- Tests for the jump functionality
---
--- This test suite validates the next/previous note navigation,
--- keyword filtering, and cursor positioning functionality.
---

local helpers = require("spec.spec_helper")

describe("screw.jump", function()
  local jump
  local mock_notes
  local test_buffer_info

  before_each(function()
    helpers.setup_test_env()

    -- Mock buffer info for tests
    test_buffer_info = {
      filepath = "/tmp/test-project/test.lua",
      relative_path = "test.lua",
      line_number = 15,
    }

    -- Mock config module
    package.loaded["screw.config"] = {
      get_option = function(option)
        if option == "signs" then
          return {
            keywords = {
              vulnerable = { "VULN", "SECURITY", "XSS" },
              todo = { "TODO", "FIXME" },
              not_vulnerable = { "SAFE", "OK" },
            },
          }
        end
        return {}
      end,
    }

    -- Mock utils functions
    package.loaded["screw.utils"] = {
      get_buffer_info = function()
        return test_buffer_info
      end,
      info = function(msg)
        _G.test_info_message = msg
      end,
    }

    -- Mock storage module
    package.loaded["screw.notes.storage"] = {
      get_all_notes = function()
        return mock_notes or {}
      end,
    }

    -- Mock cursor and window operations
    _G.test_cursor_position = { 15, 0 } -- line, column
    _G.test_cursor_moves = {}

    vim.api.nvim_win_get_cursor = function()
      return _G.test_cursor_position
    end

    vim.api.nvim_win_set_cursor = function(win, pos)
      _G.test_cursor_position = pos
      table.insert(_G.test_cursor_moves, { line = pos[1], col = pos[2] })
    end

    vim.cmd = function(command)
      -- Track centering commands
      if command == "normal! zz" then
        _G.test_centered = true
      end
    end

    -- Create test notes for test.lua
    mock_notes = {
      helpers.create_mock_note({
        id = "note-1",
        file_path = "test.lua",
        line_number = 5,
        state = "vulnerable",
        severity = "high",
        comment = "XSS vulnerability in user input handling",
      }),
      helpers.create_mock_note({
        id = "note-2",
        file_path = "test.lua",
        line_number = 10,
        state = "todo",
        comment = "TODO: Add input validation here",
      }),
      helpers.create_mock_note({
        id = "note-3",
        file_path = "test.lua",
        line_number = 25,
        state = "not_vulnerable",
        severity = "low",
        comment = "This code is safe from SQL injection",
      }),
      helpers.create_mock_note({
        id = "note-4",
        file_path = "test.lua",
        line_number = 30,
        state = "vulnerable",
        severity = "medium",
        comment = "Potential buffer overflow here needs review",
      }),
      helpers.create_mock_note({
        id = "note-5",
        file_path = "other.lua",
        line_number = 15,
        state = "vulnerable",
        comment = "Note in different file",
      }),
    }

    -- Reset module and create new instance
    package.loaded["screw.jump"] = nil
    jump = require("screw.jump")
  end)

  after_each(function()
    helpers.cleanup_test_files()

    -- Clean up test globals
    _G.test_info_message = nil
    _G.test_cursor_position = nil
    _G.test_cursor_moves = nil
    _G.test_centered = nil
  end)

  describe("jump_next", function()
    it("should jump to next note after current line", function()
      -- Start at line 15, should jump to line 25
      _G.test_cursor_position = { 15, 0 }

      jump.jump_next()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(25, _G.test_cursor_moves[1].line)
      assert.equal(0, _G.test_cursor_moves[1].col)
      assert.is_true(_G.test_centered)
    end)

    it("should wrap to first note when at end", function()
      -- Start at line 35 (after all notes), should wrap to line 5
      _G.test_cursor_position = { 35, 0 }

      jump.jump_next()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(5, _G.test_cursor_moves[1].line)
    end)

    it("should show info message about the note", function()
      _G.test_cursor_position = { 1, 0 } -- Before first note

      jump.jump_next()

      assert.is_string(_G.test_info_message)
      assert.matches("Note VULNERABLE %[HIGH%]", _G.test_info_message)
      assert.matches("XSS vulnerability", _G.test_info_message)
    end)

    it("should truncate long comment in info message", function()
      -- Create a note with very long comment
      mock_notes[1].comment = string.rep("a", 100) -- 100 character comment
      _G.test_cursor_position = { 1, 0 }

      jump.jump_next()

      assert.matches("%.%.%.", _G.test_info_message) -- Should contain "..."
    end)

    it("should handle note without severity", function()
      mock_notes[1].severity = nil
      _G.test_cursor_position = { 1, 0 }

      jump.jump_next()

      assert.matches("Note VULNERABLE:", _G.test_info_message)
      assert.not_matches("%[", _G.test_info_message) -- No severity brackets
    end)

    it("should filter by keywords when specified", function()
      _G.test_cursor_position = { 1, 0 }

      -- Jump with TODO keyword filter - should skip vulnerable notes
      jump.jump_next({ keywords = { "TODO" } })

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(10, _G.test_cursor_moves[1].line) -- Should jump to TODO note
    end)

    it("should handle no matching notes for keyword filter", function()
      _G.test_cursor_position = { 1, 0 }

      jump.jump_next({ keywords = { "NONEXISTENT" } })

      assert.equal(0, #_G.test_cursor_moves) -- Should not move cursor
      assert.matches("No security notes matching NONEXISTENT found", _G.test_info_message)
    end)

    it("should handle empty buffer", function()
      test_buffer_info.filepath = ""

      jump.jump_next()

      assert.equal(0, #_G.test_cursor_moves)
      assert.matches("No security notes found", _G.test_info_message)
    end)

    it("should handle buffer with no notes", function()
      mock_notes = {}

      jump.jump_next()

      assert.equal(0, #_G.test_cursor_moves)
      assert.matches("No security notes found", _G.test_info_message)
    end)

    it("should only consider notes in current file", function()
      test_buffer_info.relative_path = "other.lua"
      _G.test_cursor_position = { 1, 0 }

      jump.jump_next()

      -- Should jump to note in other.lua at line 15
      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(15, _G.test_cursor_moves[1].line)
    end)

    it("should handle case-insensitive keyword matching", function()
      _G.test_cursor_position = { 1, 0 }

      -- Use lowercase keyword that should match uppercase in config
      jump.jump_next({ keywords = { "vuln" } })

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(5, _G.test_cursor_moves[1].line) -- Should find vulnerable note
    end)
  end)

  describe("jump_prev", function()
    it("should jump to previous note before current line", function()
      -- Start at line 20, should jump to line 10
      _G.test_cursor_position = { 20, 0 }

      jump.jump_prev()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(10, _G.test_cursor_moves[1].line)
      assert.equal(0, _G.test_cursor_moves[1].col)
      assert.is_true(_G.test_centered)
    end)

    it("should wrap to last note when at beginning", function()
      -- Start at line 1 (before all notes), should wrap to line 30
      _G.test_cursor_position = { 1, 0 }

      jump.jump_prev()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(30, _G.test_cursor_moves[1].line)
    end)

    it("should show info message about the note", function()
      _G.test_cursor_position = { 35, 0 } -- After last note

      jump.jump_prev()

      assert.is_string(_G.test_info_message)
      assert.matches("Note VULNERABLE %[MEDIUM%]", _G.test_info_message)
      assert.matches("buffer overflow", _G.test_info_message)
    end)

    it("should filter by keywords when specified", function()
      _G.test_cursor_position = { 35, 0 }

      jump.jump_prev({ keywords = { "SAFE" } })

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(25, _G.test_cursor_moves[1].line) -- Should jump to not_vulnerable note
    end)

    it("should handle no matching notes for keyword filter", function()
      _G.test_cursor_position = { 35, 0 }

      jump.jump_prev({ keywords = { "NONEXISTENT" } })

      assert.equal(0, #_G.test_cursor_moves)
      assert.matches("No security notes matching NONEXISTENT found", _G.test_info_message)
    end)

    it("should search backwards through notes", function()
      _G.test_cursor_position = { 27, 0 } -- Between line 25 and 30

      jump.jump_prev()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(25, _G.test_cursor_moves[1].line) -- Should go to previous note (25)
    end)

    it("should handle multiple keywords", function()
      _G.test_cursor_position = { 35, 0 }

      jump.jump_prev({ keywords = { "TODO", "FIXME" } })

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(10, _G.test_cursor_moves[1].line) -- Should find TODO note
    end)
  end)

  describe("note sorting", function()
    it("should sort notes by line number", function()
      -- Add notes out of order
      mock_notes = {
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 30,
          state = "vulnerable",
        }),
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 10,
          state = "todo",
        }),
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 20,
          state = "not_vulnerable",
        }),
      }

      _G.test_cursor_position = { 1, 0 }

      jump.jump_next()

      -- Should jump to line 10 (first in sorted order)
      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(10, _G.test_cursor_moves[1].line)
    end)
  end)

  describe("keyword filtering", function()
    it("should match multiple keywords for same state", function()
      -- Add note with state that has multiple keywords
      mock_notes[1].state = "vulnerable" -- Has keywords: VULN, SECURITY, XSS
      _G.test_cursor_position = { 1, 0 }

      jump.jump_next({ keywords = { "SECURITY" } })

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(5, _G.test_cursor_moves[1].line)
    end)

    it("should handle empty keywords array", function()
      _G.test_cursor_position = { 1, 0 }

      jump.jump_next({ keywords = {} })

      -- Should behave like no filter
      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(5, _G.test_cursor_moves[1].line)
    end)

    it("should handle nil keywords", function()
      _G.test_cursor_position = { 1, 0 }

      jump.jump_next({ keywords = nil })

      -- Should behave like no filter
      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(5, _G.test_cursor_moves[1].line)
    end)

    it("should handle state with no configured keywords", function()
      -- Create note with state that has no keywords in config
      mock_notes = {
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 10,
          state = "unknown_state",
        }),
      }

      _G.test_cursor_position = { 1, 0 }

      jump.jump_next({ keywords = { "ANYTHING" } })

      assert.equal(0, #_G.test_cursor_moves) -- Should not match
    end)
  end)

  describe("edge cases", function()
    it("should handle cursor exactly on note line", function()
      _G.test_cursor_position = { 10, 0 } -- Exactly on note at line 10

      jump.jump_next()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(25, _G.test_cursor_moves[1].line) -- Should jump to next note
    end)

    it("should handle single note in buffer", function()
      mock_notes = {
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 20,
          state = "vulnerable",
        }),
      }

      _G.test_cursor_position = { 10, 0 }

      jump.jump_next()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(20, _G.test_cursor_moves[1].line)

      -- From after the note, should wrap back to same note
      _G.test_cursor_position = { 30, 0 }
      _G.test_cursor_moves = {}

      jump.jump_next()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(20, _G.test_cursor_moves[1].line)
    end)

    it("should handle notes at line 1", function()
      mock_notes = {
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 1,
          state = "vulnerable",
        }),
      }

      _G.test_cursor_position = { 10, 0 }

      jump.jump_prev()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(1, _G.test_cursor_moves[1].line)
    end)

    it("should handle very large line numbers", function()
      mock_notes = {
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 999999,
          state = "vulnerable",
        }),
      }

      _G.test_cursor_position = { 1, 0 }

      jump.jump_next()

      assert.equal(1, #_G.test_cursor_moves)
      assert.equal(999999, _G.test_cursor_moves[1].line)
    end)
  end)

  describe("state formatting", function()
    it("should format underscore states correctly", function()
      mock_notes = {
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 10,
          state = "not_vulnerable",
          comment = "Safe code",
          severity = nil, -- Remove severity to test underscore formatting
        }),
      }

      _G.test_cursor_position = { 1, 0 }

      jump.jump_next()

      assert.matches("Note NOT VULNERABLE", _G.test_info_message)
    end)

    it("should format severity correctly", function()
      mock_notes = {
        helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 10,
          state = "vulnerable",
          severity = "critical",
          comment = "Bad bug",
        }),
      }

      _G.test_cursor_position = { 1, 0 }

      jump.jump_next()

      assert.matches("%[CRITICAL%]", _G.test_info_message)
    end)
  end)
end)
