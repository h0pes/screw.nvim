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
---@field lualine? screw.LualineConfig Lualine statusline integration

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
---@field sarif? screw.SarifImportConfig SARIF import configuration
---@field auto_map_cwe? boolean Auto-map tool findings to CWE (default: true)

---@class screw.SarifImportConfig
---@field collision_strategy? "ask"|"skip"|"overwrite"|"merge" How to handle collisions (default: "ask")
---@field default_author? string Default author for imported notes (default: "sarif-import")
---@field preserve_metadata? boolean Store import metadata (default: true)
---@field show_progress? boolean Show progress for large imports (default: false)

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
---@field vulnerable_imported? string Icon for imported vulnerable notes (default: "🔺")
---@field not_vulnerable_imported? string Icon for imported not vulnerable notes (default: "☑️")
---@field todo_imported? string Icon for imported todo notes (default: "📋")

---@class screw.SignColorsConfig
---@field vulnerable? string Color for vulnerable signs (default: "#f87171")
---@field not_vulnerable? string Color for not vulnerable signs (default: "#34d399")
---@field todo? string Color for todo signs (default: "#fbbf24")
---@field vulnerable_imported? string Color for imported vulnerable signs (default: "#dc2626")
---@field not_vulnerable_imported? string Color for imported not vulnerable signs (default: "#16a34a")
---@field todo_imported? string Color for imported todo signs (default: "#d97706")

---@class screw.SignKeywordsConfig
---@field vulnerable? string[] Keywords for vulnerable notes (default: {"VULNERABLE", "SECURITY", "EXPLOIT"})
---@field not_vulnerable? string[] Keywords for not vulnerable notes (default: {"SAFE", "SECURE", "OK"})
---@field todo? string[] Keywords for todo notes (default: {"TODO", "REVIEW", "CHECK"})

---@class screw.LualineConfig
---@field enabled? boolean Enable lualine integration (default: false)
---@field components? screw.LualineComponentsConfig Component-specific configuration

---@class screw.LualineComponentsConfig
---@field summary? screw.LualineComponentConfig Notes summary component configuration
---@field file_status? screw.LualineComponentConfig Current file status component configuration
---@field line_notes? screw.LualineComponentConfig Current line indicator component configuration
---@field collaboration? screw.LualineComponentConfig Collaboration status component configuration

---@class screw.LualineComponentConfig
---@field enabled? boolean Enable this component (default: true)
---@field format? string Format string with placeholders (e.g., "%{total_icon} %{total} %{vulnerable_icon}%{vulnerable}")
---@field icons? table<string, string> Icon mappings for component elements
---@field colors? table<string, string> Color mappings for component elements

-- Global configuration variable that users can set
-- This can be a config table, a function returning a config table, or nil
---@type screw.Config | fun():screw.Config | nil
vim.g.screw_nvim = vim.g.screw_nvim
