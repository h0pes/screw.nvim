--- Test initialization for screw.nvim

-- Add current directory to Lua path
package.path = package.path .. ";lua/?.lua;lua/?/init.lua"

-- Use the spec_helper for consistent vim mocking
require("spec.spec_helper")

-- Initialize screw plugin for testing with minimal config
local screw_config = require("screw.config")
screw_config.setup({
  storage = {
    backend = "json",
    path = "/tmp/screw_test",
    filename = "test_notes.json",
  },
})
