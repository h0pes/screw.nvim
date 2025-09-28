--- Tests for the signs management module
---
--- This test suite validates the sign placement, removal, and management
--- for visual indicators of security notes in the signcolumn.
---

local helpers = require("spec.spec_helper")

describe("screw.signs", function()
  local signs
  local mock_notes
  local test_bufnr = 1

  before_each(function()
    helpers.setup_test_env()

    -- Mock config module
    package.loaded["screw.config"] = {
      get_option = function(option)
        if option == "signs" then
          return {
            enabled = true,
            priority = 10,
            colors = {
              vulnerable = "#ff4444",
              not_vulnerable = "#44ff44",
              todo = "#ffff44",
              vulnerable_imported = "#ff6666",
              not_vulnerable_imported = "#66ff66",
              todo_imported = "#ffff66",
            },
            icons = {
              vulnerable = "●",
              not_vulnerable = "○",
              todo = "◐",
              vulnerable_imported = "▲",
              not_vulnerable_imported = "△",
              todo_imported = "◆",
            },
          }
        end
        return {}
      end,
    }

    -- Mock utils functions
    package.loaded["screw.utils"] = {
      get_relative_path = function(path)
        return path:gsub("/tmp/test%-project/", "")
      end,
      get_absolute_path = function(path)
        return "/tmp/test-project/" .. path
      end,
    }

    -- Mock notes manager
    package.loaded["screw.notes.manager"] = {
      get_notes = function()
        return mock_notes or {}
      end,
    }

    -- Mock storage module
    package.loaded["screw.notes.storage"] = {
      is_initialized = function()
        return true -- For tests, assume storage is always initialized
      end,
    }

    -- Mock main screw module
    package.loaded["screw"] = {
      get_notes = function()
        return mock_notes or {}
      end,
    }

    -- Track sign operations
    _G.test_signs_placed = {}
    _G.test_signs_removed = {}
    _G.test_sign_definitions = {}
    _G.test_highlight_groups = {}

    -- Mock vim sign functions
    vim.fn.sign_define = function(name, opts)
      _G.test_sign_definitions[name] = opts
    end

    vim.fn.sign_place = function(id, group, name, buffer, opts)
      table.insert(_G.test_signs_placed, {
        id = id,
        group = group,
        name = name,
        buffer = buffer,
        opts = opts,
      })
    end

    vim.fn.sign_unplace = function(group, opts)
      table.insert(_G.test_signs_removed, {
        group = group,
        opts = opts,
      })
    end

    -- Mock vim highlight functions
    vim.api.nvim_set_hl = function(ns_id, name, opts)
      _G.test_highlight_groups[name] = opts
    end

    -- Mock buffer operations
    vim.api.nvim_buf_get_option = function(bufnr, option)
      if option == "buftype" then
        return "" -- Regular file
      end
      return nil
    end

    vim.api.nvim_buf_get_name = function(bufnr)
      return "/tmp/test-project/test.lua"
    end

    vim.api.nvim_list_bufs = function()
      return { test_bufnr }
    end

    vim.api.nvim_buf_is_loaded = function()
      return true
    end

    vim.api.nvim_buf_is_valid = function()
      return true
    end

    -- Create test notes
    mock_notes = helpers.create_mock_notes(3)
    mock_notes[1].file_path = "test.lua"
    mock_notes[1].line_number = 10
    mock_notes[1].state = "vulnerable"

    mock_notes[2].file_path = "test.lua"
    mock_notes[2].line_number = 20
    mock_notes[2].state = "not_vulnerable"

    mock_notes[3].file_path = "other.lua"
    mock_notes[3].line_number = 5
    mock_notes[3].state = "todo"

    -- Reset module and create new instance
    package.loaded["screw.signs"] = nil
    signs = require("screw.signs")
  end)

  after_each(function()
    helpers.cleanup_test_files()

    -- Clean up globals
    _G.test_signs_placed = nil
    _G.test_signs_removed = nil
    _G.test_sign_definitions = nil
    _G.test_highlight_groups = nil
  end)

  describe("setup", function()
    it("should initialize sign definitions and highlights", function()
      signs.setup()

      -- Check sign definitions
      assert.is_table(_G.test_sign_definitions["ScrewVulnerable"])
      assert.equal("●", _G.test_sign_definitions["ScrewVulnerable"].text)
      assert.equal("ScrewSignVulnerable", _G.test_sign_definitions["ScrewVulnerable"].texthl)

      assert.is_table(_G.test_sign_definitions["ScrewNotVulnerable"])
      assert.equal("○", _G.test_sign_definitions["ScrewNotVulnerable"].text)

      assert.is_table(_G.test_sign_definitions["ScrewTodo"])
      assert.equal("◐", _G.test_sign_definitions["ScrewTodo"].text)

      -- Check imported sign definitions
      assert.is_table(_G.test_sign_definitions["ScrewVulnerableImported"])
      assert.equal("▲", _G.test_sign_definitions["ScrewVulnerableImported"].text)

      -- Check highlight groups
      assert.is_table(_G.test_highlight_groups["ScrewSignVulnerable"])
      assert.equal("#ff4444", _G.test_highlight_groups["ScrewSignVulnerable"].fg)

      assert.is_table(_G.test_highlight_groups["ScrewSignNotVulnerable"])
      assert.equal("#44ff44", _G.test_highlight_groups["ScrewSignNotVulnerable"].fg)
    end)

    it("should not setup when signs are disabled", function()
      package.loaded["screw.config"].get_option = function(option)
        if option == "signs" then
          return { enabled = false }
        end
        return {}
      end

      signs.setup()

      -- Should not have defined any signs
      assert.is_nil(next(_G.test_sign_definitions))
    end)

    it("should setup autocommands", function()
      local autocmd_called = false

      -- Mock autocommand creation
      vim.api.nvim_create_autocmd = function(events, opts)
        autocmd_called = true
        assert.is_true(type(events) == "string" or type(events) == "table")
        assert.is_function(opts.callback)
      end

      vim.api.nvim_create_augroup = function()
        return 1
      end

      signs.setup()

      assert.is_true(autocmd_called)
    end)
  end)

  describe("buffer sign management", function()
    before_each(function()
      signs.setup()
    end)

    describe("should_place_signs", function()
      it("should allow signs for regular files", function()
        local should_place = signs.should_place_signs(test_bufnr)

        assert.is_true(should_place)
      end)

      it("should reject signs for special buffer types", function()
        vim.api.nvim_buf_get_option = function(bufnr, option)
          if option == "buftype" then
            return "terminal" -- Special buffer type
          end
          return nil
        end

        local should_place = signs.should_place_signs(test_bufnr)

        assert.is_false(should_place)
      end)

      it("should reject signs for buffers without file paths", function()
        vim.api.nvim_buf_get_name = function()
          return "" -- No file path
        end

        local should_place = signs.should_place_signs(test_bufnr)

        assert.is_false(should_place)
      end)
    end)

    describe("place_buffer_signs", function()
      it("should place signs for notes in buffer", function()
        signs.place_buffer_signs(test_bufnr)

        -- Should have placed 2 signs (2 notes in test.lua)
        assert.equal(2, #_G.test_signs_placed)

        -- Check first sign (vulnerable)
        local first_sign = _G.test_signs_placed[1]
        assert.equal("screw", first_sign.group)
        assert.equal("ScrewVulnerable", first_sign.name)
        assert.equal(test_bufnr, first_sign.buffer)
        assert.equal(10, first_sign.opts.lnum)

        -- Check second sign (not_vulnerable)
        local second_sign = _G.test_signs_placed[2]
        assert.equal("ScrewNotVulnerable", second_sign.name)
        assert.equal(20, second_sign.opts.lnum)
      end)

      it("should not place signs when disabled", function()
        package.loaded["screw.config"].get_option = function()
          return { enabled = false }
        end

        signs.place_buffer_signs(test_bufnr)

        assert.equal(0, #_G.test_signs_placed)
      end)

      it("should clear existing signs before placing new ones", function()
        signs.place_buffer_signs(test_bufnr)

        -- Should have removed existing signs first
        assert.equal(1, #_G.test_signs_removed)
        assert.equal("screw", _G.test_signs_removed[1].group)
      end)

      it("should handle file with no notes", function()
        vim.api.nvim_buf_get_name = function()
          return "/tmp/test-project/empty.lua"
        end

        signs.place_buffer_signs(test_bufnr)

        -- Should only clear signs, not place any
        assert.equal(1, #_G.test_signs_removed)
        assert.equal(0, #_G.test_signs_placed)
      end)
    end)

    describe("clear_buffer_signs", function()
      it("should remove all signs from buffer", function()
        signs.clear_buffer_signs(test_bufnr)

        assert.equal(1, #_G.test_signs_removed)
        assert.equal("screw", _G.test_signs_removed[1].group)
        assert.equal(test_bufnr, _G.test_signs_removed[1].opts.buffer)
      end)
    end)
  end)

  describe("sign state priority", function()
    before_each(function()
      signs.setup()
    end)

    it("should prioritize vulnerable over other states", function()
      local notes = {
        helpers.create_mock_note({ state = "todo" }),
        helpers.create_mock_note({ state = "vulnerable" }),
        helpers.create_mock_note({ state = "not_vulnerable" }),
      }

      local state, is_imported = signs.get_priority_state(notes)

      assert.equal("vulnerable", state)
      assert.is_false(is_imported)
    end)

    it("should prioritize todo over not_vulnerable", function()
      local notes = {
        helpers.create_mock_note({ state = "not_vulnerable" }),
        helpers.create_mock_note({ state = "todo" }),
      }

      local state, is_imported = signs.get_priority_state(notes)

      assert.equal("todo", state)
    end)

    it("should prefer native over imported for same priority", function()
      local notes = {
        helpers.create_mock_note({ state = "vulnerable", source = "sarif-import" }),
        helpers.create_mock_note({ state = "vulnerable", source = "native" }),
      }

      local state, is_imported = signs.get_priority_state(notes)

      assert.equal("vulnerable", state)
      assert.is_false(is_imported) -- Should prefer native
    end)

    it("should detect imported notes", function()
      local notes = {
        helpers.create_mock_note({ state = "vulnerable", source = "sarif-import" }),
      }

      local state, is_imported = signs.get_priority_state(notes)

      assert.equal("vulnerable", state)
      assert.is_true(is_imported)
    end)
  end)

  describe("sign placement helpers", function()
    before_each(function()
      signs.setup()
    end)

    describe("place_sign", function()
      it("should place individual sign", function()
        signs.place_sign(test_bufnr, 15, "vulnerable", false)

        assert.equal(1, #_G.test_signs_placed)
        local sign = _G.test_signs_placed[1]
        assert.equal("ScrewVulnerable", sign.name)
        assert.equal(15, sign.opts.lnum)
      end)

      it("should place imported sign", function()
        signs.place_sign(test_bufnr, 25, "todo", true)

        assert.equal(1, #_G.test_signs_placed)
        local sign = _G.test_signs_placed[1]
        assert.equal("ScrewTodoImported", sign.name)
        assert.equal(25, sign.opts.lnum)
      end)

      it("should not place sign when disabled", function()
        package.loaded["screw.config"].get_option = function()
          return { enabled = false }
        end

        signs.place_sign(test_bufnr, 10, "vulnerable", false)

        assert.equal(0, #_G.test_signs_placed)
      end)
    end)

    describe("remove_sign", function()
      it("should remove specific sign", function()
        -- First place a sign to track it
        signs.place_sign(test_bufnr, 10, "vulnerable", false)

        -- Now remove it
        signs.remove_sign(test_bufnr, 10)

        assert.equal(1, #_G.test_signs_removed)
        local removal = _G.test_signs_removed[1]
        assert.equal("screw", removal.group)
        assert.is_table(removal.opts)
      end)

      it("should handle removal of non-existent sign", function()
        signs.remove_sign(test_bufnr, 999)

        -- Should not error, but also not remove anything
        assert.equal(0, #_G.test_signs_removed)
      end)
    end)

    describe("get_sign_name", function()
      it("should return correct sign name for native notes", function()
        assert.equal("ScrewVulnerable", signs.get_sign_name("vulnerable", false))
        assert.equal("ScrewNotVulnerable", signs.get_sign_name("not_vulnerable", false))
        assert.equal("ScrewTodo", signs.get_sign_name("todo", false))
      end)

      it("should return correct sign name for imported notes", function()
        assert.equal("ScrewVulnerableImported", signs.get_sign_name("vulnerable", true))
        assert.equal("ScrewNotVulnerableImported", signs.get_sign_name("not_vulnerable", true))
        assert.equal("ScrewTodoImported", signs.get_sign_name("todo", true))
      end)

      it("should return nil for invalid state", function()
        assert.is_nil(signs.get_sign_name("invalid_state", false))
      end)
    end)

    describe("generate_sign_id", function()
      it("should generate unique IDs for buffer and line", function()
        local id1 = signs.generate_sign_id(1, 10)
        local id2 = signs.generate_sign_id(1, 20)
        local id3 = signs.generate_sign_id(2, 10)

        assert.not_equal(id1, id2)
        assert.not_equal(id1, id3)
        assert.not_equal(id2, id3)
      end)

      it("should be deterministic for same inputs", function()
        local id1 = signs.generate_sign_id(1, 10)
        local id2 = signs.generate_sign_id(1, 10)

        assert.equal(id1, id2)
      end)
    end)
  end)

  describe("note event handling", function()
    before_each(function()
      signs.setup()
    end)

    describe("on_note_added", function()
      it("should update signs when note is added", function()
        local new_note = helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 30,
          state = "vulnerable",
        })

        -- Mock finding the buffer
        signs.find_buffer_by_file = function()
          return test_bufnr
        end

        -- Mock update function
        local update_called = false
        signs.update_line_signs = function(bufnr, line)
          update_called = true
          assert.equal(test_bufnr, bufnr)
          assert.equal(30, line)
        end

        signs.on_note_added(new_note)

        assert.is_true(update_called)
      end)

      it("should handle note for unopened file", function()
        local new_note = helpers.create_mock_note({
          file_path = "unopened.lua",
          line_number = 10,
        })

        signs.find_buffer_by_file = function()
          return nil -- File not open
        end

        -- Should not error
        signs.on_note_added(new_note)
      end)
    end)

    describe("on_note_deleted", function()
      it("should update signs when note is deleted", function()
        local deleted_note = helpers.create_mock_note({
          file_path = "test.lua",
          line_number = 15,
        })

        signs.find_buffer_by_file = function()
          return test_bufnr
        end

        local update_called = false
        signs.update_line_signs = function(bufnr, line)
          update_called = true
          assert.equal(test_bufnr, bufnr)
          assert.equal(15, line)
        end

        signs.on_note_deleted(deleted_note)

        assert.is_true(update_called)
      end)
    end)
  end)

  describe("utility functions", function()
    before_each(function()
      signs.setup()
    end)

    describe("find_buffer_by_file", function()
      it("should find buffer by file path", function()
        vim.api.nvim_buf_get_name = function(bufnr)
          if bufnr == test_bufnr then
            return "/tmp/test-project/test.lua"
          end
          return ""
        end

        local found_bufnr = signs.find_buffer_by_file("test.lua")

        assert.equal(test_bufnr, found_bufnr)
      end)

      it("should return nil for non-open file", function()
        local found_bufnr = signs.find_buffer_by_file("nonexistent.lua")

        assert.is_nil(found_bufnr)
      end)
    end)

    describe("refresh_all_signs", function()
      it("should refresh signs for all buffers", function()
        local redefine_called = false
        local place_called = false

        -- Mock the functions that should be called
        local original_setup_highlights = signs.setup_highlights
        local original_setup_sign_definitions = signs.setup_sign_definitions
        local original_place_buffer_signs = signs.place_buffer_signs

        signs.setup_highlights = function()
          redefine_called = true
        end

        signs.setup_sign_definitions = function()
          redefine_called = true
        end

        signs.place_buffer_signs = function()
          place_called = true
        end

        signs.refresh_all_signs()

        assert.is_true(redefine_called)
        assert.is_true(place_called)

        -- Restore original functions
        signs.setup_highlights = original_setup_highlights
        signs.setup_sign_definitions = original_setup_sign_definitions
        signs.place_buffer_signs = original_place_buffer_signs
      end)

      it("should clear all signs when disabled", function()
        package.loaded["screw.config"].get_option = function()
          return { enabled = false }
        end

        local clear_called = false
        signs.clear_all_signs = function()
          clear_called = true
        end

        signs.refresh_all_signs()

        assert.is_true(clear_called)
      end)
    end)

    describe("clear_all_signs", function()
      it("should clear signs from all buffers", function()
        -- Place some signs first
        signs.place_buffer_signs(test_bufnr)

        signs.clear_all_signs()

        -- Should have cleared signs
        assert.is_true(#_G.test_signs_removed > 0)
      end)
    end)
  end)
end)
