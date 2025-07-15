stds.nvim = {
  read_globals = {
    "vim",
    "describe",
    "it",
    "before_each",
    "after_each",
    "setup",
    "teardown",
    "assert",
    "spy",
    "stub",
    "mock",
    "busted",
    "pending",
    "finally",
    "lazy",
    "strict",
    "randomize",
    "insulate",
    "expose",
    "randomize",
    "seed",
    "async",
    "done",
    "set_timeout",
    "clear_timeout",
    "set_interval",
    "clear_interval",
    "set_immediate",
    "clear_immediate",
    "current_time",
    "current_date",
    "current_datetime",
    "current_timestamp",
    "randomseed",
    "random",
    "randomseed",
    "table",
    "string",
    "math",
    "os",
    "io",
    "coroutine",
    "package",
    "require",
    "load",
    "loadfile",
    "loadstring",
    "dofile",
    "module",
    "rawget",
    "rawset",
    "rawlen",
    "rawequal",
    "setmetatable",
    "getmetatable",
    "ipairs",
    "pairs",
    "next",
    "type",
    "tostring",
    "tonumber",
    "error",
    "pcall",
    "xpcall",
    "select",
    "unpack",
    "assert",
    "print",
    "_G",
    "_VERSION",
    "gcinfo",
    "collectgarbage",
    "newproxy",
    "getfenv",
    "setfenv"
  },
  globals = {
    "vim",
  }
}

std = "lua51+nvim"

read_globals = {
  "vim",
}

cache = true
codes = true

-- Ignore certain warnings
ignore = {
  "631",  -- line too long
  "212",  -- unused argument
  "213",  -- unused loop variable
  "611",  -- line contains only whitespace
  "614",  -- trailing whitespace
  "121",  -- setting read-only global variable
  "122",  -- setting read-only field
  "143",  -- accessing undefined variable
  "113",  -- accessing undefined variable
  "542",  -- empty if branch
  "581",  -- negation of a relational operator
  "542",  -- empty if branch
  "311",  -- value assigned to variable is unused
  "312",  -- value assigned to variable is unused
  "321",  -- variable is never accessed
  "431",  -- shadowing upvalue
  "432",  -- shadowing upvalue argument
  "433",  -- shadowing upvalue loop variable
}

-- Exclude certain directories
exclude_files = {
  "lua/screw/config/",
  ".luarocks/",
  ".git/",
}

-- Only check specific files
files = {
  "lua/",
  "spec/",
}

-- Maximum line length
max_line_length = 120

-- Maximum cyclomatic complexity
max_cyclomatic_complexity = 10