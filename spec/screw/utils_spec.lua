local helpers = require("spec.spec_helper")

describe("screw.utils", function()
  local utils

  before_each(function()
    helpers.setup_test_env()
    utils = require("screw.utils")
  end)

  after_each(function()
    helpers.cleanup_test_files()
  end)

  describe("generate_id", function()
    it("should generate a unique ID", function()
      local id1 = utils.generate_id()
      local id2 = utils.generate_id()
      
      assert.is_string(id1)
      assert.is_string(id2)
      assert.is_not.equal(id1, id2)
    end)
    
    it("should generate ID with correct format", function()
      local id = utils.generate_id()
      
      -- Should be timestamp-random format
      assert.matches("%d+%-%d+", id)
    end)
  end)

  describe("get_timestamp", function()
    it("should return ISO 8601 timestamp", function()
      local timestamp = utils.get_timestamp()
      
      assert.is_string(timestamp)
      -- Should match ISO 8601 format
      assert.matches("%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ", timestamp)
    end)
  end)

  describe("get_author", function()
    it("should return author from environment", function()
      local author = utils.get_author()
      
      assert.is_string(author)
      assert.is_not.equal(author, "")
    end)
  end)

  describe("is_valid_cwe", function()
    it("should validate correct CWE format", function()
      assert.is_true(utils.is_valid_cwe("CWE-79"))
      assert.is_true(utils.is_valid_cwe("CWE-89"))
      assert.is_true(utils.is_valid_cwe("CWE-1234"))
    end)
    
    it("should reject invalid CWE format", function()
      assert.is_false(utils.is_valid_cwe("cwe-79"))
      assert.is_false(utils.is_valid_cwe("CWE79"))
      assert.is_false(utils.is_valid_cwe("CWE-"))
      assert.is_false(utils.is_valid_cwe("79"))
      assert.is_false(utils.is_valid_cwe(""))
    end)
  end)

  describe("is_valid_state", function()
    it("should validate correct states", function()
      assert.is_true(utils.is_valid_state("vulnerable"))
      assert.is_true(utils.is_valid_state("not_vulnerable"))
      assert.is_true(utils.is_valid_state("todo"))
    end)
    
    it("should reject invalid states", function()
      assert.is_false(utils.is_valid_state("invalid"))
      assert.is_false(utils.is_valid_state(""))
      assert.is_false(utils.is_valid_state("VULNERABLE"))
      assert.is_false(utils.is_valid_state("not-vulnerable"))
    end)
  end)

  describe("is_valid_severity", function()
    it("should validate correct severity levels", function()
      assert.is_true(utils.is_valid_severity("high"))
      assert.is_true(utils.is_valid_severity("medium"))
      assert.is_true(utils.is_valid_severity("low"))
      assert.is_true(utils.is_valid_severity("info"))
    end)
    
    it("should reject invalid severity levels", function()
      assert.is_false(utils.is_valid_severity("critical"))
      assert.is_false(utils.is_valid_severity(""))
      assert.is_false(utils.is_valid_severity("HIGH"))
      assert.is_false(utils.is_valid_severity("moderate"))
    end)
  end)

  describe("get_project_root", function()
    it("should return project root directory", function()
      local root = utils.get_project_root()
      
      assert.is_string(root)
      assert.is_not.equal(root, "")
    end)
  end)

  describe("get_buffer_info", function()
    it("should return buffer information", function()
      local info = utils.get_buffer_info()
      
      assert.is_table(info)
      assert.is_string(info.filepath)
      assert.is_string(info.relative_path)
      assert.is_number(info.line_number)
    end)
  end)

  describe("get_absolute_path", function()
    it("should convert relative path to absolute", function()
      local relative = "test.lua"
      local absolute = utils.get_absolute_path(relative)
      
      assert.is_string(absolute)
      assert.is_true(absolute:sub(1, 1) == "/")
    end)
    
    it("should handle already absolute paths", function()
      local absolute = "/tmp/test.lua"
      local result = utils.get_absolute_path(absolute)
      
      assert.equal(absolute, result)
    end)
  end)

  describe("ensure_dir", function()
    it("should create directory if it doesn't exist", function()
      local result = utils.ensure_dir("/tmp/test-dir")
      
      assert.is_true(result)
    end)
  end)

  describe("write_file", function()
    it("should write content to file", function()
      local result = utils.write_file("/tmp/test.txt", "test content")
      
      assert.is_true(result)
    end)
  end)

  describe("read_file", function()
    it("should read file content", function()
      local content = utils.read_file("/tmp/test.txt")
      
      assert.is_string(content)
    end)
  end)
end)