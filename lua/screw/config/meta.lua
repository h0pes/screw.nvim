--- Configuration meta types for screw.nvim
---
--- This file defines the external API configuration types with optional fields
--- to provide a clean interface for users while supporting LSP completion.
---

---@class screw.Config
---@field storage? screw.StorageConfig Storage configuration
---@field ui? screw.UIConfig UI configuration
---@field collaboration? screw.CollaborationConfig Collaboration settings
---@field export? screw.ExportConfig Export settings
---@field import? screw.ImportConfig Import settings
---@field signs? screw.SignsConfig Sign column configuration

---@class screw.StorageConfig
---@field backend? "json"|"sqlite" Storage backend type (default: "json")
---@field path? string Custom storage directory path (defaults to project root)
---@field filename? string Custom storage filename (default: "screw_notes_<timestamp>.json")
---@field auto_save? boolean Auto-save notes on changes (default: true)

---@class screw.UIConfig
---@field float_window? screw.FloatConfig Float window configuration
---@field highlights? screw.HighlightConfig Syntax highlighting

---@class screw.FloatConfig
---@field width? number|string Window width (default: 80)
---@field height? number|string Window height (default: 20)
---@field border? "none"|"single"|"double"|"rounded"|"solid"|"shadow" Border style (default: "rounded")
---@field winblend? number Window transparency 0-100 (default: 0)

---@class screw.HighlightConfig
---@field note_marker? string Highlight group for note markers (default: "DiagnosticInfo")
---@field vulnerable? string Highlight group for vulnerable notes (default: "DiagnosticError")
---@field not_vulnerable? string Highlight group for safe notes (default: "DiagnosticOk")
---@field todo? string Highlight group for todo notes (default: "DiagnosticWarn")

---@class screw.CollaborationConfig
---@field enabled? boolean Enable collaboration mode (default: false)
---@field database_url? string Database connection URL
---@field sync_interval? number Sync interval in milliseconds (default: 1000)

---@class screw.ExportConfig
---@field default_format? "markdown"|"json"|"csv" Default export format (default: "markdown")
---@field output_dir? string Output directory for exports (defaults to project root)

---@class screw.ImportConfig
---@field supported_tools? string[] List of supported SAST tools
---@field auto_map_cwe? boolean Auto-map tool findings to CWE (default: true)

---@class screw.SignsConfig
---@field enabled? boolean Enable signs in signcolumn (default: true)
---@field priority? number Sign priority level (default: 8)
---@field icons? screw.SignIconsConfig Sign icons for different states
---@field colors? screw.SignColorsConfig Sign colors for different states
---@field keywords? screw.SignKeywordsConfig Keywords for search/telescope integration

---@class screw.SignIconsConfig
---@field vulnerable? string Icon for vulnerable notes (default: "🔴")
---@field not_vulnerable? string Icon for not vulnerable notes (default: "✅")
---@field todo? string Icon for todo notes (default: "📝")

---@class screw.SignColorsConfig
---@field vulnerable? string Color for vulnerable signs (default: "#f87171")
---@field not_vulnerable? string Color for not vulnerable signs (default: "#34d399")
---@field todo? string Color for todo signs (default: "#fbbf24")

---@class screw.SignKeywordsConfig
---@field vulnerable? string[] Keywords for vulnerable notes (default: {"VULNERABLE", "SECURITY", "EXPLOIT"})
---@field not_vulnerable? string[] Keywords for not vulnerable notes (default: {"SAFE", "SECURE", "OK"})
---@field todo? string[] Keywords for todo notes (default: {"TODO", "REVIEW", "CHECK"})

-- Global configuration variable that users can set
-- This can be a config table, a function returning a config table, or nil
---@type screw.Config | fun():screw.Config | nil
vim.g.screw_nvim = vim.g.screw_nvim