# screw.nvim

<div align="center">

[![Neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org/)
[![Security](https://img.shields.io/badge/Security-Critical-red?style=for-the-badge&logo=security&logoColor=white)](https://owasp.org/)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://github.com/h0pes/screw.nvim/blob/main/LICENSE)

---

[📖 Documentation](#documentation) •
[🐛 Report Bug](https://github.com/h0pes/screw.nvim/issues) •
[💡 Request Feature](https://github.com/h0pes/screw.nvim/issues)

</div>

**screw.nvim** is a powerful Neovim plugin designed to streamline security code reviews. It provides comprehensive note-taking capabilities integrated directly into your editor, supporting collaboration, SAST tool integration, and detailed vulnerability tracking.

By default, security notes are stored in timestamped files (e.g., `screw_notes_20240708_143022.json`) in your project root, with full customization available for different storage locations and naming conventions.

> [!NOTE]
> This plugin is specifically designed for security analysts and developers performing security-focused code reviews. It's not a general-purpose note-taking tool.

## :sparkles: Features

- **🔒 Security-focused annotations** - Attach vulnerability notes to specific lines of code
- **🏷️ CWE classification** - Track findings with Common Weakness Enumeration identifiers
- **⚠️ Severity levels** - Classify vulnerabilities as High, Medium, Low, or Info with mandatory severity for vulnerable findings
- **📍 Visual signcolumn indicators** - Color-coded signs for instant vulnerability state recognition
- **📝 Threaded discussions** - BBS-style reply chains with chronological sorting
- **✏️ Full CRUD operations** - Create, Read, Update, Delete notes with author validation
- **🎨 Smart UI** - Floating windows with save confirmation and intelligent note selection
- **💾 Persistent storage** - Auto-save notes with timestamped filenames and graceful project lifecycle management
- **📊 Export capabilities** - Generate reports in Markdown, JSON, and CSV formats
- **🔧 SAST integration** - Import findings from Semgrep, Bandit, Gosec, SonarQube
- **👥 Real-time collaboration** - Multi-user support with conflict resolution and threaded discussions
- **🔍 Advanced search** - Telescope integration with fuzzy search across all note fields
- **🔍 Health diagnostics** - Comprehensive troubleshooting and validation

## :package: Installation

### lazy.nvim

```lua
{
  "h0pes/screw.nvim",
  version = "^1", -- Recommended: pin to major version
  cmd = "Screw", -- Lazy-load on command
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  }
}
```

<details>
<summary>Alternative installation methods</summary>

#### packer.nvim

```lua
-- Minimal setup (plugin works out of the box)
use "h0pes/screw.nvim"

-- With custom configuration (optional)
use {
  "h0pes/screw.nvim",
  config = function()
    require("screw").setup({
      -- your configuration comes here
      -- or leave it empty to use the default settings
    })
  end
}
```

#### vim-plug

```vim
Plug 'h0pes/screw.nvim'
" No configuration needed - plugin works out of the box!

" Optional: customize configuration
" lua require("screw").setup({ storage = { backend = "sqlite" } })
```

</details>

## :rocket: Quick Start

> [!IMPORTANT]
> **Zero Configuration Required!** screw.nvim works immediately after installation with sensible defaults. Notes are automatically stored in timestamped files like `screw_notes_20240708_143022.json` in your project root. The `setup()` function is completely optional and only needed for custom configuration.

> [!TIP]
> Run `:checkhealth screw` after installation to verify everything is working correctly.

### 1. Create your first security note

Position your cursor on a suspicious line and run:

```vim
:Screw note add
```

Fill in the floating window form:
- **Comment** (required): Your security observation
- **Description** (optional): Detailed analysis
- **CWE** (optional): e.g., `CWE-79` for XSS
- **State**: `vulnerable`, `not_vulnerable`, or `todo`
- **Severity** (required if state is `vulnerable`, optional otherwise): `high`, `medium`, `low`, or `info`

When you close the window (Esc/q), you'll be prompted to save if changes were made.

> [!TIP]
> **Visual Indicators**: After creating a note, you'll see a color-coded sign in the signcolumn (🔴 for vulnerable, ✅ for not vulnerable, 📝 for todo) that provides instant visual feedback about the security state of each line.

### 2. View existing notes

```vim
:Screw note view line    " Notes for current line
:Screw note view file    " All notes in current file  
:Screw note view all     " Project-wide notes
```

### 3. Edit and manage notes

```vim
:Screw note edit     " Edit note on current line (shows selection if multiple)
:Screw note delete   " Delete note on current line (with confirmation)
:Screw note reply    " Add reply to existing note (threaded discussion)
```

**Note**: Only the original author can edit or delete their notes.

### 4. Visual signcolumn indicators

screw.nvim automatically displays color-coded signs in the signcolumn to provide instant visual feedback:

- 🔴 **Vulnerable** - Red signs for confirmed security vulnerabilities
- ✅ **Not Vulnerable** - Green signs for reviewed and confirmed safe code
- 📝 **Todo** - Yellow signs for pending security reviews

**Key Features:**
- **Auto-appears** - Signs automatically show when you open files with existing notes
- **Smart priority** - When multiple notes exist on the same line, shows the highest priority (vulnerable > todo > not vulnerable)
- **Real-time updates** - Signs instantly update when you create, edit, or delete notes
- **Configurable** - Customize icons, colors, and priority levels
- **Performance optimized** - Uses dedicated namespace to avoid conflicts with other plugins

### 5. Search through security notes

> [!TIP]
> **Telescope Integration**: Install telescope.nvim for powerful search capabilities!

```vim
" Search all notes with telescope (requires telescope.nvim)
:Screw search

" Search specific states or CWEs
:Screw search --state vulnerable
:Screw search --cwe CWE-89

" Or use telescope directly after loading extension
:Telescope screw notes
```

**Interactive Search**: In the telescope picker, type to search across all fields:
- `vulnerable` - Find vulnerable notes
- `CWE-89` - Find specific CWE entries
- `injection` - Find notes mentioning injection
- `alice high` - Find Alice's high severity notes

### 6. Export security report

```vim
:Screw export markdown /path/to/security-report.md
```

## :gear: Configuration

> [!NOTE]
> **Configuration is entirely optional.** The plugin works perfectly with zero configuration using intelligent defaults. Only configure what you want to change from the defaults.

screw.nvim comes with the following defaults:

```lua
{
  -- Storage configuration
  storage = {
    backend = "json",           -- Storage backend: "json" or "sqlite"
    path = nil,                 -- Defaults to project root directory
    filename = nil,             -- Auto-generated with timestamp: "screw_notes_<timestamp>.json"
    auto_save = true,           -- Auto-save notes on changes
  },

  -- UI configuration
  ui = {
    float_window = {
      width = 80,               -- Window width (number or "50%")
      height = 20,              -- Window height (number or "50%")
      border = "rounded",       -- Border style: "none"|"single"|"double"|"rounded"|"solid"|"shadow"
      winblend = 0,             -- Window transparency (0-100)
    },
    highlights = {
      note_marker = "DiagnosticInfo",      -- General note indicators
      vulnerable = "DiagnosticError",      -- Vulnerable state text
      not_vulnerable = "DiagnosticOk",     -- Not vulnerable state text
      todo = "DiagnosticWarn",             -- Todo state text
      field_title = "Title",               -- Field titles in UI forms
      field_info = "Comment",              -- Field descriptions in UI forms
    },
  },

  -- Collaboration configuration (HTTP multi-user support)
  collaboration = {
    enabled = false,           -- Enable HTTP collaboration (disabled by default)
    api_url = nil,            -- HTTP API URL (from SCREW_API_URL env var)
    user_id = nil,            -- User ID (from SCREW_USER_EMAIL/SCREW_USER_ID env)
    connection_timeout = 10000, -- HTTP request timeout (ms)
    max_retries = 3,          -- Max connection retry attempts
  },

  -- Export configuration
  export = {
    default_format = "markdown", -- Default export format: "markdown"|"json"|"csv"|"sarif"
    output_dir = nil,           -- Defaults to project root
  },

  -- Import configuration
  import = {
    sarif = {
      collision_strategy = "ask", -- How to handle collisions: "ask"|"skip"|"overwrite"|"merge"
      default_author = "sarif-import", -- Default author for imported notes
      preserve_metadata = true,   -- Store import metadata (tool, timestamps, rule IDs)
      show_progress = false,      -- Show progress for large imports
    },
    auto_map_cwe = true,          -- Auto-classify SARIF findings with CWE
  },

  -- Signs configuration
  signs = {
    enabled = true,             -- Enable signcolumn indicators
    priority = 8,               -- Sign priority level
    icons = {
      -- Native notes
      vulnerable = "🔴",        -- Icon for vulnerable notes
      not_vulnerable = "✅",    -- Icon for not vulnerable notes  
      todo = "📝",              -- Icon for todo notes
      -- Imported notes (from SARIF)
      vulnerable_imported = "🔺",    -- Icon for imported vulnerable notes
      not_vulnerable_imported = "☑️", -- Icon for imported not vulnerable notes
      todo_imported = "📋",          -- Icon for imported todo notes
    },
    colors = {
      -- Native notes
      vulnerable = "#f87171",   -- Red color for vulnerable signs
      not_vulnerable = "#34d399", -- Green color for not vulnerable signs
      todo = "#fbbf24",         -- Yellow color for todo signs
      -- Imported notes (slightly different shades)
      vulnerable_imported = "#dc2626",    -- Darker red for imported vulnerable
      not_vulnerable_imported = "#16a34a", -- Darker green for imported safe
      todo_imported = "#d97706",          -- Darker yellow for imported todo
    },
    keywords = {                -- Keywords for jump navigation and filtering
      vulnerable = { "VULNERABLE", "FIXME", "BUG", "ISSUE", "VULNERABILITY", "SECURITY", "EXPLOIT" },
      not_vulnerable = { "FALSE POSITIVE", "SECURE", "SAFE", "OK" },
      todo = { "TODO", "INFO", "WARNING", "CHECK", "REVIEW" }
    }
  },
}
```

### Example Configurations

<details>
<summary>SQLite storage with custom path</summary>

```lua
{
  "h0pes/screw.nvim",
  opts = {
    storage = {
      backend = "sqlite",
      path = vim.fn.stdpath("data") .. "/screw",
      filename = "security_notes.db"
    }
  }
}
```

</details>

<details>
<summary>HTTP collaboration mode</summary>

**Prerequisites:**
```bash
# Deploy collaboration server
./deploy_server.sh

# Set environment variables
export SCREW_API_URL="http://your-server:3000/api"
export SCREW_USER_EMAIL="analyst@company.com"
```

**Configuration:**
```lua
{
  "h0pes/screw.nvim",
  opts = {
    storage = {
      backend = "http",  -- Use HTTP backend for collaboration
    },
    collaboration = {
      enabled = true,
      connection_timeout = 10000,  -- 10 second timeout
      max_retries = 3,
    }
  }
}
```

> **Note**: See [Collaboration Guide](COLLABORATION.md) for complete setup instructions.

</details>

<details>
<summary>SARIF import with custom settings</summary>

```lua
{
  "h0pes/screw.nvim",
  opts = {
    import = {
      sarif = {
        collision_strategy = "skip", -- Skip conflicts instead of asking
        default_author = "security-scan",
        preserve_metadata = true,
        show_progress = true
      }
    },
    signs = {
      icons = {
        vulnerable_imported = "❌",
        not_vulnerable_imported = "✅", 
        todo_imported = "❓"
      }
    }
  }
}
```

</details>

<details>
<summary>Custom UI and signs</summary>

```lua
{
  "h0pes/screw.nvim",
  opts = {
    ui = {
      float_window = {
        width = 100,
        height = 25,
        border = "double",
        winblend = 10
      }
    },
    signs = {
      icons = {
        vulnerable = "❌",
        not_vulnerable = "✅",
        todo = "❓"
      },
      colors = {
        vulnerable = "#ff4444",
        not_vulnerable = "#44ff44",
        todo = "#ffff44"
      }
    }
  }
}
```

</details>


### Custom keymaps

> [!IMPORTANT]  
> screw.nvim follows Neovim best practices and provides **no default keymaps**. You must configure them explicitly using the provided `<Plug>` mappings.

#### Available `<Plug>` Mappings

The plugin provides the following `<Plug>` mappings for user customization:

| `<Plug>` Mapping | Description | Function |
|------------------|-------------|----------|
| `<Plug>(ScrewCreateNote)` | Create security note at cursor | Core note creation |
| `<Plug>(ScrewEditNote)` | Edit existing note | Note modification |
| `<Plug>(ScrewDeleteNote)` | Delete existing note | Note removal |
| `<Plug>(ScrewReplyToNote)` | Reply to existing note | Threaded discussions |
| `<Plug>(ScrewViewLineNotes)` | View notes for current line | Line-specific notes |
| `<Plug>(ScrewViewFileNotes)` | View notes for current file | File-wide notes |
| `<Plug>(ScrewViewAllNotes)` | View all project notes | Project overview |
| `<Plug>(ScrewExportMarkdown)` | Export to Markdown | Quick export |
| `<Plug>(ScrewJumpNext)` | Jump to next security note | Navigation |
| `<Plug>(ScrewJumpPrev)` | Jump to previous security note | Navigation |
| `<Plug>(ScrewStats)` | Show project statistics | Analytics |

#### Recommended Configuration

```lua
-- Essential keymaps for security review workflow
vim.keymap.set("n", "<leader>sn", "<Plug>(ScrewCreateNote)", { desc = "Create security note" })
vim.keymap.set("n", "<leader>se", "<Plug>(ScrewEditNote)", { desc = "Edit security note" })
vim.keymap.set("n", "<leader>sd", "<Plug>(ScrewDeleteNote)", { desc = "Delete security note" })
vim.keymap.set("n", "<leader>sr", "<Plug>(ScrewReplyToNote)", { desc = "Reply to note" })
vim.keymap.set("n", "<leader>sv", "<Plug>(ScrewViewLineNotes)", { desc = "View line notes" })
vim.keymap.set("n", "<leader>sf", "<Plug>(ScrewViewFileNotes)", { desc = "View file notes" })
vim.keymap.set("n", "<leader>sa", "<Plug>(ScrewViewAllNotes)", { desc = "View all notes" })

-- Navigation mappings (similar to todo-comments.nvim style)
vim.keymap.set("n", "]s", "<Plug>(ScrewJumpNext)", { desc = "Next security note" })
vim.keymap.set("n", "[s", "<Plug>(ScrewJumpPrev)", { desc = "Previous security note" })

-- Optional convenience mappings
vim.keymap.set("n", "<leader>sx", "<Plug>(ScrewExportMarkdown)", { desc = "Export to Markdown" })
vim.keymap.set("n", "<leader>ss", "<Plug>(ScrewStats)", { desc = "Security stats" })
```

#### Alternative Keymap Styles

```lua
-- Minimal setup (just note creation)
vim.keymap.set("n", "<leader>n", "<Plug>(ScrewCreateNote)")

-- Vim-style commands
vim.keymap.set("n", "<leader>c", "<Plug>(ScrewCreateNote)")  -- c for create
vim.keymap.set("n", "<leader>v", "<Plug>(ScrewViewLineNotes)")  -- v for view

-- Function key bindings
vim.keymap.set("n", "<F9>", "<Plug>(ScrewCreateNote)")
vim.keymap.set("n", "<F10>", "<Plug>(ScrewViewLineNotes)")

-- Which-key.nvim integration
local wk = require("which-key")
wk.register({
  s = {
    name = "Security Review",
    n = { "<Plug>(ScrewCreateNote)", "Create note" },
    e = { "<Plug>(ScrewEditNote)", "Edit note" },
    d = { "<Plug>(ScrewDeleteNote)", "Delete note" },
    r = { "<Plug>(ScrewReplyToNote)", "Reply to note" },
    v = { "<Plug>(ScrewViewLineNotes)", "View line notes" },
    f = { "<Plug>(ScrewViewFileNotes)", "View file notes" },
    a = { "<Plug>(ScrewViewAllNotes)", "View all notes" },
    x = { "<Plug>(ScrewExportMarkdown)", "Export markdown" },
    s = { "<Plug>(ScrewStats)", "Statistics" },
  }
}, { prefix = "<leader>" })
```

## :computer: Commands

All commands are scoped under `:Screw` with intelligent tab completion and file path assistance:

### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `:Screw note add` | Create note at cursor position | `:Screw note add` |
| `:Screw note edit` | Edit existing note | `:Screw note edit` |
| `:Screw note delete [line\|file\|project]` | Delete existing note(s) | `:Screw note delete line` |
| `:Screw note reply` | Add reply to existing note | `:Screw note reply` |
| `:Screw note view {line\|file\|all}` | View notes by scope | `:Screw note view line` |
| `:Screw export {format} [path]` | Export security report | `:Screw export sarif report.sarif` |
| `:Screw import {tool} <path>` | Import SAST results | `:Screw import semgrep results.json` |
| `:Screw jump {next\|prev} [keywords...]` | Jump to next/prev note | `:Screw jump next FIXME BUG` |
| `:Screw search [options]` | Search notes with Telescope | `:Screw search --state vulnerable` |
| `:Screw stats` | Display project statistics | `:Screw stats` |

### Command Details

#### :memo: Note Management

```vim
" Create a new security note at cursor position
:Screw note add

" Edit an existing note (shows selection if multiple notes on line)
:Screw note edit

" Delete an existing note (shows selection if multiple notes on line)  
:Screw note delete

" Delete all notes in the current file (with confirmation)
:Screw note delete file

" Delete all notes in the project (with confirmation)
:Screw note delete project

" Add a reply to an existing note (threaded discussion)
:Screw note reply
```

**Create/Edit Window Features:**
- **Comment** (required): Your security observation
- **Description** (optional): Detailed vulnerability analysis  
- **CWE** (optional): Common Weakness Enumeration ID (e.g., `CWE-79`)
- **State**: `vulnerable`, `not_vulnerable`, or `todo`
- **Severity** (required if state is `vulnerable`, optional otherwise): `high`, `medium`, `low`, or `info`
- **Save confirmation**: Prompts to save only when changes are detected
- **Author validation**: Only original authors can edit/delete their notes

**Keybindings in note windows:**
- `<CR>` - Save and close
- `<Esc>` or `q` - Close (with save prompt if changes detected)

**Selection Interface:**
When multiple notes exist on the same line:
- Numbered selection list with note previews
- Shows author, timestamp, state, and comment excerpt
- Press number key to select, `<Esc>` to cancel

#### :eyes: Viewing Notes

```vim
" View notes for current line
:Screw note view line

" View all notes in current file
:Screw note view file

" View all notes across the project
:Screw note view all
```

**Enhanced Thread Display:**
- ✅ **BBS-style threading**: Replies shown with classic bulletin board separators
- ✅ **Chronological sorting**: Replies ordered by timestamp
- ✅ **Rich metadata**: Shows author, creation date, state, and CWE information
- ✅ **Thread counters**: Displays number of replies per note
- ✅ **Clean separators**: Visual distinction between notes and thread boundaries

**Example Thread Display:**
```
## Thread (2 replies)

────────────────────────────────────────────────────────────────────
From: alice | Date: 2024-01-15T10:30:00Z

This looks like a SQL injection vulnerability. The user input isn't sanitized.

────────────────────────────────────────────────────────────────────
From: bob | Date: 2024-01-15T14:22:00Z

Confirmed. I tested this with a simple ' OR 1=1 -- payload and it works.

────────────────────────────────────────────────────────────────────
End of thread
```

**Navigation:**
- ✅ Read-only display with `<Esc>`/`q` to close
- ✅ Syntax highlighting for different vulnerability states

#### :outbox_tray: Export Reports

```vim
" Export to Markdown (default format)
:Screw export markdown

" Export to JSON with custom path
:Screw export json /path/to/security-report.json

" Export to CSV for spreadsheet analysis
:Screw export csv vulnerability-summary.csv

" Export to SARIF format for security tools integration
:Screw export sarif security-findings.sarif
```

**Export Options:**
- **Formats**: `markdown`, `json`, `csv`, `sarif`
- **Path completion**: Tab complete for output file paths
- **Automatic timestamping**: Files auto-named with timestamp if no path specified
- **Filtered exports**: Only export notes matching specific criteria
- **🤝 Collaboration mode**: Export works seamlessly with both local storage and collaboration databases (PostgreSQL/HTTP API)

**SARIF Export Features:**
- **SARIF v2.1.0 compliant** - Full compatibility with industry standard
- **Rich metadata** - Includes tool information, rules, and CWE mappings
- **Security tool integration** - Compatible with GitHub Security, CodeQL, and other SARIF consumers
- **Threaded discussions** - Preserves reply threads in result properties
- **Severity mapping** - Maps screw severity levels to SARIF levels (error/warning/note/none)

**Export Features:**
- ✅ Include/exclude reply threads
- ✅ Filter by vulnerability state, author, or CWE
- ✅ Professional formatting with metadata
- ✅ Compatible with security reporting tools

#### :inbox_tray: Import from SAST Tools

```vim
" Import SARIF report from any SAST tool
:Screw import sarif /path/to/report.sarif

" Examples with different tools
:Screw import sarif bandit-results.sarif
:Screw import sarif semgrep-output.sarif
:Screw import sarif gosec-report.sarif
:Screw import sarif sonarqube-findings.sarif
```

**SARIF Import Features:**
- **🌐 Universal compatibility** - Works with any SARIF v2.1.0 compliant tool (Bandit, Semgrep, Gosec, SonarQube, CodeQL, etc.)
- **🔄 Smart collision detection** - Handles overlapping findings intelligently with user choice
- **📝 Source tracking** - Differentiates imported vs. native notes with distinct visual indicators
- **🏷️ Metadata preservation** - Retains tool name, rule IDs, confidence levels, and import timestamps
- **⚡ Batch processing** - Import hundreds of findings efficiently
- **🎯 Path resolution** - Automatically converts absolute paths to project-relative paths
- **🔍 CWE extraction** - Automatically extracts CWE classifications from SARIF rule metadata
- **🤝 Collaboration mode** - Import works seamlessly with both local storage and collaboration databases (PostgreSQL/HTTP API)

**Collision Handling:**
When importing finds conflicts with existing notes, you can choose to:
- **Ask** (default) - Prompt for each collision
- **Skip** - Skip conflicting imports  
- **Overwrite** - Replace existing notes
- **Keep both** - Import alongside existing notes

**Visual Differentiation:**
Imported notes show distinct signcolumn icons:
- 🔺 Imported vulnerable (vs 🔴 native)
- ☑️ Imported safe (vs ✅ native)
- 📋 Imported todo (vs 📝 native)

#### :bar_chart: Statistics

```vim
" Display comprehensive project statistics
:Screw stats
```

**Statistics Include:**
- 📊 Total notes count
- 🔴 Vulnerable findings count
- 🟢 Not vulnerable count  
- 🟡 Todo/pending review count
- ⚠️ Severity breakdown (High, Medium, Low, Info)
- 📁 Files with security annotations
- 👥 Notes by author breakdown
- 🏷️ CWE classification summary

#### :arrow_right: Navigation

```vim
" Jump to next security note in current buffer
:Screw jump next

" Jump to previous security note in current buffer
:Screw jump prev

" Jump to next note matching specific keywords
:Screw jump next FIXME BUG VULNERABILITY

" Jump to previous note matching specific keywords  
:Screw jump prev TODO WARNING
```

**Navigation Features:**
- **Buffer scope** - Only navigates notes within the current file
- **Keyword filtering** - Optional filtering by state-specific keywords
- **Wrapping** - Automatically wraps to beginning/end when reaching boundaries
- **Visual feedback** - Shows brief note info when jumping
- **Centering** - Automatically centers the target line in window

**Available Keywords by State:**
- **Vulnerable**: `VULNERABLE`, `FIXME`, `BUG`, `ISSUE`, `VULNERABILITY`, `SECURITY`, `EXPLOIT`
- **Not Vulnerable**: `FALSE POSITIVE`, `SECURE`, `SAFE`, `OK`
- **Todo**: `TODO`, `INFO`, `WARNING`, `CHECK`, `REVIEW`

#### :mag: Search with Telescope

> [!NOTE]
> Search functionality requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) to be installed and configured.

```vim
" Search all security notes in project (default)
:Screw search

" Search notes in current file only
:Screw search --file

" Search by vulnerability state
:Screw search --state vulnerable
:Screw search --state not_vulnerable
:Screw search --state todo

" Search by severity
:Screw search --severity high
:Screw search --severity medium

" Search by CWE
:Screw search --cwe CWE-89

" Search by author
:Screw search --author alice

" Search by keywords in comment/description
:Screw search --keywords sql injection
:Screw search -k xss csrf

" Combine multiple filters
:Screw search --file --state vulnerable --severity high
:Screw search --state todo --keywords TODO FIXME
```

**Search Features:**
- **🔍 Advanced fuzzy search** - Search through all note fields simultaneously
- **📂 Scope filtering** - Search in current file or entire project
- **🏷️ State filtering** - Filter by vulnerability state (vulnerable/not_vulnerable/todo)
- **⚠️ Severity filtering** - Filter by severity level (high/medium/low/info)
- **🔖 CWE filtering** - Filter by specific Common Weakness Enumeration
- **👤 Author filtering** - Filter by note author
- **🔎 Multi-field search** - Search across file paths, comments, descriptions, states, CWEs, severity, and authors
- **⌨️ Quick actions** - Jump to note, edit, or delete directly from search results
- **📍 Live preview** - Real-time file content preview with syntax highlighting

**Telescope Integration:**
- **Default action** (`<CR>`) - Jump to note location and show details
- **Edit action** (`<C-e>`) - Jump to note and open edit dialog
- **Delete action** (`<C-d>`) - Jump to note and open delete confirmation

**Alternative Telescope Commands:**
```vim
" Direct telescope commands (requires telescope extension loaded)
:Telescope screw notes          " Search all notes
:Telescope screw file_notes     " Search current file notes
:Telescope screw vulnerable     " Search vulnerable notes only
:Telescope screw todo          " Search todo notes only
:Telescope screw cwe           " Search by CWE (prompts for CWE ID)
```

**Interactive Search in Telescope:**

The telescope picker provides a powerful search interface where you can type to dynamically filter results. The search operates across all note fields:

**What You Can Search For:**
- **States**: `vulnerable`, `not_vulnerable`, `todo`
- **CWE IDs**: `CWE-89`, `CWE-79`, `CWE-1336`, etc.
- **Severity**: `high`, `medium`, `low`, `info`
- **Authors**: Username of note creators
- **File paths**: `SAST/python`, `injection/servers`, etc.
- **Comments & descriptions**: Any text content from notes
- **Line numbers**: `:7`, `:16` (with colon prefix)

**Example Interactive Searches:**
```
todo                    # Find all todo items
vulnerable              # Find all vulnerable notes  
CWE-1336               # Find notes with specific CWE
high                   # Find high severity notes
injection              # Find notes mentioning injection
alice vulnerable       # Find Alice's vulnerable notes
CWE-78 high            # Find high severity CWE-78 notes
SAST python todo       # Find todo items in SAST python files
```

**Search Behavior:**
- **Fuzzy matching** - Partial matches work (`vulner` matches `vulnerable`)
- **Case insensitive** - `TODO`, `todo`, and `Todo` all work
- **Multi-term search** - All terms must be found somewhere in the entry
- **Real-time filtering** - Results update as you type
- **Highlighted matches** - Search terms are highlighted in results

**Setup Telescope Extension:**
```lua
-- Load the extension
require("telescope").load_extension("screw")

-- Optional keymaps
vim.keymap.set("n", "<leader>ss", ":Telescope screw notes<CR>", { desc = "Search security notes" })
vim.keymap.set("n", "<leader>sf", ":Telescope screw file_notes<CR>", { desc = "Search notes in current file" })
vim.keymap.set("n", "<leader>sv", ":Telescope screw vulnerable<CR>", { desc = "Search vulnerable notes" })
vim.keymap.set("n", "<leader>st", ":Telescope screw todo<CR>", { desc = "Search todo notes" })
```

### Tab Completion

The plugin provides intelligent tab completion for all commands:

```vim
:Screw <Tab>                    " → note, export, import, stats, jump, search
:Screw note <Tab>               " → add, edit, delete, reply, view
:Screw note view <Tab>          " → line, file, all
:Screw note delete <Tab>        " → line, file, project
:Screw export <Tab>             " → markdown, json, csv, sarif
:Screw export sarif <Tab>       " → file path completion
:Screw import <Tab>             " → semgrep, bandit, gosec, sonarqube
:Screw import semgrep <Tab>     " → file path completion
:Screw jump <Tab>               " → next, prev
:Screw jump next <Tab>          " → VULNERABLE, FIXME, BUG, TODO, etc.
:Screw search <Tab>             " → --file, --project, --state, --severity, --cwe, --author, --keywords
```

### Advanced Usage

#### Filtered Operations

```vim
" Export only vulnerable findings
:Screw export markdown vuln-report.md

" View notes by specific author (via API)
:lua require("screw").get_notes({ author = "security-team" })

" Export with custom filter
:lua require("screw").export_notes({ 
  format = "json", 
  output_path = "critical-findings.json",
  filter = { state = "vulnerable", cwe = "CWE-89" }
})
```

#### Batch Operations

```vim
" Import multiple SAST tool results
:Screw import semgrep semgrep-results.json
:Screw import bandit bandit-results.json
:Screw import gosec gosec-results.json

" Then export comprehensive SARIF report for security tools
:Screw export sarif complete-security-analysis.sarif
```

#### SARIF Integration Workflow

```vim
" 1. Import findings from multiple SAST tools
:Screw import semgrep semgrep-results.json
:Screw import bandit bandit-results.json

" 2. Review and annotate findings manually
:Screw note add

" 3. Export combined results to SARIF for CI/CD integration
:Screw export sarif final-security-report.sarif

" 4. Use in GitHub Security tab, CodeQL, or other SARIF-compatible tools
```

**SARIF Use Cases:**
- **GitHub Security Integration** - Upload SARIF files to GitHub Security tab
- **CI/CD Pipeline Integration** - Include SARIF reports in automated workflows
- **Security Tool Interoperability** - Exchange findings between different security tools
- **Compliance Reporting** - Generate standardized security reports for audits

## :electric_plug: API

### Programmatic note creation

```lua
local screw = require("screw")

-- Create vulnerability note
screw.create_note({
  comment = "SQL injection in user input handling",
  description = "User input from request parameter is directly interpolated into SQL query without sanitization",
  cwe = "CWE-89", 
  state = "vulnerable",
  severity = "high"  -- Required when state is "vulnerable"
})

-- Query notes
local vulnerable_notes = screw.get_notes({ state = "vulnerable" })
local high_severity_notes = screw.get_notes({ severity = "high" })
local critical_vulns = screw.get_notes({ state = "vulnerable", severity = "high" })
local line_notes = screw.get_current_line_notes()

-- Export and import
screw.export_notes({ 
  format = "sarif", 
  output_path = "/tmp/security-findings.sarif",
  filter = { state = "vulnerable", severity = "high" }
})

screw.import_notes({ 
  tool = "semgrep", 
  input_path = "/tmp/semgrep-results.json",
  auto_classify = true
})

-- Navigation (similar to todo-comments.nvim)
screw.jump_next()  -- Jump to next note
screw.jump_prev()  -- Jump to previous note

-- Jump with keyword filtering
screw.jump_next({ keywords = { "FIXME", "BUG" } })
screw.jump_prev({ keywords = { "TODO", "WARNING" } })
```

### Hook system

```lua
local notes = require("screw.notes")

-- Register pre-creation hook
notes.register_hook("pre_create", function(note_data)
  print("Creating note:", note_data.comment)
end)

-- Register post-creation hook  
notes.register_hook("post_create", function(note)
  print("Note created with ID:", note.id)
end)
```

## :busts_in_silhouette: Collaboration

**HTTP-powered multi-user security reviews** with zero client dependencies, real-time synchronization, offline support, and enterprise-grade scalability.

### :rocket: Quick Setup

**1. Deploy collaboration server:**
```bash
# Run the automated deployment script
./deploy_server.sh
```

**2. Configure client environment:**
```bash
export SCREW_API_URL="http://your-server:3000/api"
export SCREW_USER_EMAIL="analyst@company.com"
```

**3. Enable collaboration in your plugin configuration:**
```lua
require("screw").setup({
  storage = {
    backend = "http",  -- Use HTTP backend
  },
  collaboration = {
    enabled = true,
  }
})
```

### :sparkles: Key Features

- **🌐 Zero Dependencies** - No PostgreSQL drivers needed on clients, just curl
- **📡 HTTP-based Architecture** - Simple REST API with FastAPI server and PostgreSQL backend
- **🔄 Real-time sync** - See changes from other users instantly via cache refresh
- **📡 Offline mode** - Automatic graceful degradation with operation queuing
- **🚀 Easy Deployment** - Single Python server with automated deployment scripts
- **👤 User ownership** - Only note authors can edit/delete their notes, others can reply
- **⚡ Performance optimized** - Efficient local caching and connection management
- **🔐 Secure by design** - Environment-based credentials, HTTPS support, firewall-friendly
- **📊 Full import/export support** - All import/export functionality works identically in collaboration mode

### :computer: Collaboration Commands

```vim
" Core collaboration
:Screw status                     " Show collaboration connection status
:Screw sync                       " Manual synchronization with server
:Screw reconnect                  " Force server reconnection

" All note operations automatically sync in collaborative mode
:Screw note add                   " Create note (syncs to server)
:Screw note edit                  " Edit note (syncs to server)
:Screw note delete                " Delete note (syncs to server)
:Screw note reply                 " Add reply (syncs to server)
```

### :gear: Advanced Configuration

```lua
-- Minimal setup - uses default local mode
require("screw").setup()

-- Enable collaborative mode with custom settings
require("screw").setup({
  storage = {
    backend = "http",  -- Use HTTP backend for collaboration
  },
  collaboration = {
    enabled = true,
    connection_timeout = 10000,   -- 10 second HTTP timeout
    max_retries = 3,             -- Connection retry attempts
  }
})
```

### :warning: Environment Setup

**Required environment variables for collaboration:**
```bash
# HTTP API server connection (required)
export SCREW_API_URL="http://your-server:3000/api"

# User identification (required - choose one)
export SCREW_USER_EMAIL="your.email@company.com"
export SCREW_USER_ID="your-username"
```

> **📖 Complete Guide**: See [COLLABORATION.md](COLLABORATION.md) for detailed setup instructions, server deployment, HTTP API configuration, troubleshooting, and advanced usage patterns.

### Threaded Discussions

screw.nvim supports rich threaded discussions for collaborative security reviews:

```vim
" Start a discussion by replying to any note
:Screw note reply
```

**Thread Features:**
- **Chronological ordering** - Replies sorted by timestamp
- **Visual separators** - Clean BBS-style thread boundaries  
- **Metadata display** - Author and timestamp for each reply
- **Nested discussions** - Multi-level conversations about findings
- **Real-time sync** - Instant collaboration in team environments

**Example Use Cases:**
- **Vulnerability confirmation** - Team members can confirm/dispute findings
- **Remediation discussion** - Collaborative planning for fixing issues  
- **Knowledge sharing** - Explaining attack vectors and mitigation strategies
- **Code review feedback** - Detailed discussions about specific security concerns

## :inbox_tray: SAST Integration

Import findings from popular security tools:

### Semgrep

```bash
# Run Semgrep and import results
semgrep --config=auto --json --output=results.json /path/to/code
```

```vim
:Screw import semgrep results.json
```

### Bandit (Python)

```bash
bandit -r /path/to/python/code -f json -o bandit-results.json
```

```vim
:Screw import bandit bandit-results.json  
```

### Supported formats

| Tool | Format | Auto-CWE Mapping | Notes |
|------|--------|------------------|-------|
| Semgrep | JSON | ✅ | Full metadata support |
| Bandit | JSON | ✅ | Python-specific rules |
| Gosec | JSON | ✅ | Go security analysis |
| SonarQube | JSON | ✅ | Export via API |

## :hospital: Health Check

screw.nvim provides comprehensive health diagnostics for troubleshooting:

```vim
:checkhealth screw
```

### Health Check Coverage

The enhanced health check system validates:

#### **🔧 Environment & Dependencies**
- ✅ Neovim version compatibility (>= 0.9.0)
- ✅ Required Neovim features (Lua, floating windows, timers)
- ✅ Lua built-in modules (os, io, string, table, math, json)
- ✅ Neovim API availability (vim.fn, vim.api, vim.loop, etc.)
- ✅ Optional external tools (ripgrep, fd, git)

#### **⚙️ Configuration & Initialization**
- ✅ Plugin loading and module initialization
- ✅ User configuration validation and structure
- ✅ Configuration section completeness
- ✅ Dynamic configuration function support
- ✅ Unknown key detection and validation

#### **💾 Storage System**
- ✅ Storage backend functionality (JSON/SQLite)
- ✅ Directory creation and write permissions
- ✅ Storage file validation and integrity
- ✅ Storage statistics and metadata
- ✅ Backup and recovery capabilities

#### **🚀 Plugin Functionality**
- ✅ Core module loading (notes, UI, export, import, signs)
- ✅ Basic plugin operations testing
- ✅ Statistics generation functionality
- ✅ Command system integrity
- ✅ Signcolumn indicators functionality

#### **👥 Collaboration Features**
- ✅ Collaboration module loading
- ✅ API URL configuration and format
- ✅ HTTP server connectivity (basic checks)
- ✅ Sync mechanism functionality

#### **⚠️ Issue Detection**
- ✅ Conflicting plugin detection
- ✅ Performance impact assessment
- ✅ Large note collection warnings
- ✅ Common configuration pitfalls

### Health Check Output

```vim
==============================================================================
screw.nvim: health#check
==============================================================================

Neovim Environment ~
• Neovim version: 0.9.2 (>= 0.9.0 required) |OK|
• Lua support available |OK|
• Floating windows available |OK|

Plugin Loading ~
• Main plugin module loaded successfully |OK|
• Configuration management module loaded |OK|
• Type definitions module loaded |OK|

User Configuration ~
• Custom user configuration detected |INFO|
• User configuration is valid |OK|
• Configuration accessible |OK|

Storage System ~
• Storage backend: json |INFO|
• Storage directory exists |OK|
• Write permissions verified |OK|
• Storage backend functional |OK|

Health Check Summary ~
• All health checks passed - screw.nvim is ready to use |OK|
```

### Troubleshooting

If health checks fail:

1. **Check the specific error section** - Each check provides detailed error messages
2. **Review configuration** - Ensure your vim.g.screw_nvim or setup() configuration is valid
3. **Verify permissions** - Ensure write access to storage directories
4. **Update Neovim** - Ensure you're running Neovim >= 0.9.0
5. **Check dependencies** - Install optional tools if needed for enhanced features

## :page_facing_up: Documentation

<details>
<summary>Complete documentation index</summary>

- [Installation Guide](docs/installation.md)
- [Configuration Reference](docs/configuration.md)
- [API Documentation](docs/api.md)
- [Collaboration Setup](docs/collaboration.md)
- [SAST Integration](docs/sast-integration.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Contributing](docs/contributing.md)

</details>

## :warning: Requirements

- **Neovim** >= 0.9.0
- **curl** (usually pre-installed, for HTTP collaboration)
- **No external dependencies** for basic functionality
- **telescope.nvim** (optional, for search functionality)

## :zap: Performance & Lazy Loading

screw.nvim is designed for **zero-impact startup performance**:

- **🚀 Smart Initialization** - Plugin components load only when first used
- **⚡ Lazy Module Loading** - No modules are required until a command is executed
- **🎯 Minimal Footprint** - Only loads what you actually use
- **⏱️ Instant Startup** - No startup time penalty regardless of plugin size

### Loading Behavior

```lua
-- ✅ Plugin installation: Zero impact on startup time
-- ✅ First `:Screw` command: Loads only needed components
-- ✅ Subsequent commands: Already loaded, instant response
-- ✅ Setup() call: Optional, only for custom configuration
```

The plugin follows Neovim best practices and **never loads eagerly** - everything is loaded on-demand when you actually use the functionality.

## :building_construction: Development

### Running tests

```bash
# Run all tests
make test

# Run with coverage
make coverage
```

### Project structure

```
screw.nvim/
├── lua/screw/           # Core plugin code
│   ├── notes/          # Note management
│   ├── export/         # Export modules  
│   ├── import/         # Import modules
│   └── collaboration/ # Real-time features
├── doc/               # Help documentation
└── spec/              # Test suite
```

## :handshake: Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

### Development workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `make test && make lint`
5. Submit a pull request

## :memo: License

[MIT License](LICENSE) © 2024

## :heart: Acknowledgments

- Inspired by [RefactorSecurity's VSCode plugin](https://github.com/RefactorSecurity/vscode-security-notes)
- Built following [nvim-best-practices](https://github.com/nvim-neorocks/nvim-best-practices)
- Thanks to the Neovim community for excellent plugin development resources

---

<div align="center">

**Star :star: this repo if you find it useful!**

[Report Issues](https://github.com/h0pes/screw.nvim/issues) • [Request Features](https://github.com/h0pes/screw.nvim/issues) • [Contribute](CONTRIBUTING.md)

</div>