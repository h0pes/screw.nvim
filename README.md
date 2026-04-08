<p align="center">
  <img width="360" height="360" alt="screw" src="https://github.com/user-attachments/assets/9d5c5072-27e3-4e0f-95ee-643531648a7b" />
</p>

<p align="center">
  <b>
    A plugin to perform secure code review in 
    <a href="https://neovim.io" target="_blank">Neovim</a>
  </b>
</p>

<p align="center">
  <a href="doc/">📖 Documentation</a> •
  <a href="https://github.com/h0pes/screw.nvim/issues">🐛 Report Bug</a> •
  <a href="https://github.com/h0pes/screw.nvim/issues">💡 Request Feature</a>
</p>

<p align="center">
  <a href="https://neovim.io/">
    <img src="https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white" alt="Neovim" />
  </a>
  <a href="https://www.lua.org/">
    <img src="https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white" alt="Lua" />
  </a>
  <a href="https://owasp.org/">
    <img src="https://img.shields.io/badge/OWASP-Compliant-blue?style=for-the-badge&logo=owasp&logoColor=white" alt="OWASP" />
  </a>
  <a href="https://cwe.mitre.org/">
    <img src="https://img.shields.io/badge/CWE-Compatible-purple?style=for-the-badge&logo=security&logoColor=white" alt="CWE" />
  </a>
  <a href="https://sarifweb.azurewebsites.net/">
    <img src="https://img.shields.io/badge/SARIF-Compatible-green?style=for-the-badge&logo=github&logoColor=white" alt="SARIF" />
  </a>
  <a href="https://github.com/h0pes/screw.nvim">
    <img src="https://img.shields.io/badge/Security-Analysis-orange?style=for-the-badge&logo=shield&logoColor=white" alt="Security Analysis" />
  </a>
</p>

<p align="center">
  <a href="https://github.com/h0pes/screw.nvim/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License: MIT" />
  </a>
</p>



https://github.com/user-attachments/assets/a9fa35d6-cd8c-41c7-b247-8916c70454aa


---

</div>

**screw.nvim** is a powerful Neovim plugin designed to streamline security code reviews. It provides comprehensive note-taking capabilities integrated directly into your editor, supporting collaboration, SAST tool integration and detailed vulnerability tracking.

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
- **💾 Flexible storage modes** - Local JSON/SQLite storage (default) or HTTP collaboration via Python server with PostgreSQL backend
- **📊 Export capabilities** - Generate reports in Markdown, JSON, and CSV formats
- **🔧 SAST integration** - Import findings from other AST tools leveraging the SARIF format
- **👥 Real-time collaboration** - Optional multi-user mode with HTTP API, conflict resolution and threaded discussions
- **🔍 Advanced search** - Telescope integration with fuzzy search across all note fields
- **📊 Lualine integration** - Display security notes information directly in your statusline with customizable components
- **🔍 Health diagnostics** - Comprehensive troubleshooting and validation

## :bookmark_tabs: Contents

<details>
<summary><a href="#package-installation">Installation</a></summary>

- [lazy.nvim](#lazynvim)
- [Alternative installation methods](#alternative-installation-methods)

</details>

<details>
<summary><a href="#rocket-quick-start">Quick Start</a></summary>

- [1. Create your first security note](#1-create-your-first-security-note)
- [2. View existing notes](#2-view-existing-notes)
- [3. Edit and manage notes](#3-edit-and-manage-notes)
- [4. Visual signcolumn indicators](#4-visual-signcolumn-indicators)
- [5. Search through security notes](#5-search-through-security-notes)
- [6. Export security report](#6-export-security-report)
- [7. Import security findings](#7-import-security-findings)
- [8. View project statistics](#8-view-project-statistics)
- [9. Navigate between notes](#9-navigate-between-notes)

</details>

<details>
<summary><a href="#gear-configuration">Configuration</a></summary>

- [Example Configurations](#example-configurations)
- [Custom keymaps](#custom-keymaps)

</details>

<details>
<summary><a href="#keyboard-keymap-reference">Keymap Reference</a></summary>

- [Core Note Management](#core-note-management)
- [Note Viewing & Navigation](#note-viewing--navigation)
- [Export & Analytics](#export--analytics)

</details>

<details>
<summary><a href="#art-available-highlight-groups">Available Highlight Groups</a></summary>

- [Sign Column Highlights](#sign-column-highlights)
- [Float Window UI Highlights](#float-window-ui-highlights)
- [Configuration-Based Highlighting](#configuration-based-highlighting)

</details>

<details>
<summary><a href="#computer-commands">Commands</a></summary>

- [Core Commands](#core-commands)
- [Command Details](#command-details)
- [Tab Completion](#tab-completion)

</details>

<details>
<summary><a href="#chart_with_upwards_trend-lualine-integration">Lualine Integration</a></summary>

- [Available Components](#sparkles-available-components)
- [Setup](#gear-setup)
- [Customization](#art-customization)
- [Usage Examples](#bulb-usage-examples)
- [Component Details](#information_source-component-details)
- [Requirements](#warning-requirements)
- [Troubleshooting](#mag-troubleshooting)
- [Advanced Usage](#advanced-usage)

</details>

<details>
<summary><a href="#electric_plug-api">API</a></summary>

- [Programmatic note creation](#programmatic-note-creation)
- [Hook system](#hook-system)

</details>

<details>
<summary><a href="#busts_in_silhouette-collaboration">Collaboration</a></summary>

- [Quick Setup](#rocket-quick-setup)
- [Key Features](#sparkles-key-features)
- [Collaboration Usage](#computer-collaboration-usage)
- [Advanced Configuration](#gear-advanced-configuration)
- [Environment Setup](#warning-environment-setup)
- [Threaded Discussions](#threaded-discussions)

</details>

<details>
<summary><a href="#inbox_tray-ast-integration">AST Integration</a></summary>

- [Semgrep](#semgrep)
- [Bandit (Python)](#bandit-python)
- [Supported formats](#supported-formats)

</details>

<details>
<summary><a href="#hospital-health-check">Health Check</a></summary>

- [Health Check Coverage](#health-check-coverage)
- [Health Check Output](#health-check-output)
- [Troubleshooting](#troubleshooting-1)

</details>

<details>
<summary><a href="#zap-performance--lazy-loading">Performance & Lazy Loading</a></summary>

- [Loading Behavior](#loading-behavior)

</details>

<details>
<summary><a href="#building_construction-development">Development</a></summary>

- [Running tests](#running-tests)
- [Project structure](#project-structure)

</details>

<details>
<summary><a href="#handshake-contributing">Contributing</a></summary>

- [Development workflow](#development-workflow)

</details>

<details>
<summary><a href="#page_facing_up-documentation">Documentation</a></summary>

</details>

<details>
<summary><a href="#warning-requirements">Requirements</a></summary>

</details>

<details>
<summary><a href="#memo-license">License</a></summary>

</details>

<details>
<summary><a href="#heart-acknowledgments">Acknowledgments</a></summary>

</details>

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

_I have not personally tested these installation methods as I use `Lazy` as package manager._

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
> **Visual Indicators**: After creating a note, you'll see a color-coded sign in the signcolumn (🔴 for vulnerable, ✅ for not vulnerable, 📝 for todo) that provides instant visual feedback about the security state of each line. These signs can be customized in the plugin settings configuration.

### 2. View existing notes

```vim
:Screw note view line    " Notes for current line
:Screw note view file    " All notes in current file
:Screw note view project     " Project-wide notes
```



https://github.com/user-attachments/assets/72c33ea6-23d1-4fbe-9f3b-13348c81db87



### 3. Edit and manage notes

```vim
:Screw note edit     " Edit note on current line (shows selection if multiple)
:Screw note delete   " Default options without specifying context, delete note on current line (with confirmation)
:Screw note delete line " Same as previous command
:Screw note delete file " Delete notes in current opened file
:Screw note delete project " Delete notes in current project
:Screw note reply    " Add reply to existing note (threaded discussion)
```



https://github.com/user-attachments/assets/789bdf85-289c-4154-b6b8-7dfed5e2d235



https://github.com/user-attachments/assets/3c959166-4dd4-43a8-b0c1-77eb7a86142c



https://github.com/user-attachments/assets/c0dc2db0-d6e3-4a3a-a129-30fe937d9c65





> [!NOTE]
> **Only the original author can edit or delete their notes.**

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
" Basic searches (requires telescope.nvim)
:Screw search                        " Search all notes in project
:Screw search --file                 " Search current file only
:Screw search -f                     " Short form for --file

" Filter by vulnerability state
:Screw search --state vulnerable     " Find confirmed vulnerabilities
:Screw search --state todo           " Find pending reviews
:Screw search --state not_vulnerable " Find reviewed safe code
:Screw search -s vulnerable          " Short form

" Filter by severity and CWE
:Screw search --severity high        " High priority findings only
:Screw search --cwe CWE-89          " SQL injection findings
:Screw search --author alice         " Notes by specific author

" Search by keywords in comments/descriptions
:Screw search --keywords injection   " Find notes mentioning injection
:Screw search -k xss csrf           " Multiple keywords (short form)

" Combine multiple filters
:Screw search --file --state vulnerable --severity high
:Screw search --keywords sql --cwe CWE-89 --author security-team

" Direct telescope commands (alternative)
:Telescope screw notes               " Same as :Screw search
:Telescope screw file_notes         " Same as :Screw search --file
```

**Interactive Search**: In the telescope picker, type to search across all fields:

- `vulnerable` - Find vulnerable notes
- `CWE-89` - Find specific CWE entries
- `injection` - Find notes mentioning injection
- `alice high` - Find Alice's high severity notes



https://github.com/user-attachments/assets/97ed1793-215f-4fcd-b255-11cbdd77eb25



### 6. Export security report

```vim
" Export formats available: markdown (default), json, csv, sarif
:Screw export markdown /path/to/security-report.md  " Professional markdown report
:Screw export json /path/to/findings.json           " Structured JSON data
:Screw export csv /path/to/spreadsheet.csv          " CSV for analysis
:Screw export sarif /path/to/findings.sarif         " SARIF standard format

" Auto-timestamped files (if no path specified)
:Screw export markdown                               " Creates screw_notes_YYYYMMDD_HHMMSS.md
```



https://github.com/user-attachments/assets/f44803f6-b5a7-48a1-ba9e-646ae8f05e94



**Markdown Template Features:**

- **Professional header** with generation timestamp and summary
- **Table of contents** with file navigation links
- **File-organized sections** with notes grouped by file
- **Structured note format** including state, CWE, severity, and threaded replies
- **Rich metadata** with author, timestamps, and vulnerability classifications

### 7. Import security findings

```vim
" Import SARIF reports from security tools (universal format)
:Screw import sarif /path/to/security-findings.sarif

" Supported SARIF-compatible tools:
:Screw import sarif semgrep-results.sarif           " Semgrep findings
:Screw import sarif bandit-output.sarif             " Bandit (Python) results
:Screw import sarif gosec-report.sarif              " Gosec (Go) findings
:Screw import sarif sonarqube-export.sarif          " SonarQube results
```

**Import Features:**

- **Universal SARIF support** - Compatible with any SARIF v2.1.0 compliant tool
- **Smart collision handling** - Choose to skip, overwrite, or merge conflicting findings
- **Visual differentiation** - Imported notes show distinct icons (🔺 vs 🔴 for vulnerable)
- **Metadata preservation** - Retains tool information, rule IDs, and CWE mappings

### 8. View project statistics

```vim
:Screw stats
```

**Statistics Dashboard:**

- 📊 **Total notes count** - Complete project overview
- 🔴 **Vulnerable findings** - Critical security issues needing attention
- 🟡 **Todo items** - Pending security reviews
- 🟢 **Reviewed safe** - Code confirmed as secure
- ⚠️ **Severity breakdown** - High/Medium/Low/Info classification
- 📁 **Files coverage** - Files with security annotations
- 👥 **Author activity** - Team contribution analysis

### 9. Navigate between notes

```vim
" Jump between security notes in current buffer
:Screw jump next                     " Next note in current file
:Screw jump prev                     " Previous note in current file

" Filter by keywords (based on note content/state)
:Screw jump next FIXME BUG          " Jump to next FIXME/BUG note
:Screw jump prev TODO REVIEW        " Jump to previous TODO/REVIEW note
:Screw jump next VULNERABLE          " Jump to next vulnerable finding
```

**Navigation Features:**

- **Buffer-scoped** - Only jumps within the current open file
- **Keyword filtering** - Find notes containing specific terms
- **Smart wrapping** - Automatically wraps to beginning/end of file
- **Visual centering** - Centers the target line in the window

## :gear: Configuration

> [!NOTE]
> **Configuration is entirely optional.** The plugin works perfectly with zero configuration using intelligent defaults. Only configure what you want to change from the defaults.

screw.nvim comes with the following defaults:

```lua
{
  -- Storage configuration
  storage = {
    backend = "json",           -- Storage backend: "json"|"sqlite"|"http"
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
    project_name = nil,       -- Auto-detected from git/directory
    sync_interval = 5000,     -- HTTP polling interval (ms)
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

  -- Lualine integration (optional)
  lualine = {
    enabled = false,             -- Enable lualine statusline integration (default: false)
    components = {
      summary = {
        enabled = true,          -- Enable project-wide notes summary component
        format = "%{total_icon} %{total} %{vulnerable_icon}%{vulnerable} %{todo_icon}%{todo} %{safe_icon}%{not_vulnerable}",
        icons = {
          total = "🔍",         -- Icon for total notes count (project-wide)
          vulnerable = "🔴",    -- Icon for vulnerable notes (project-wide)
          not_vulnerable = "✅", -- Icon for safe notes (project-wide)
          todo = "📝",          -- Icon for todo notes (project-wide)
          safe = "✅",          -- Icon for safe notes (project-wide)
        },
      },
      file_status = {
        enabled = true,          -- Enable current file status component
        format = "%{file_icon} %{count} notes",
        icons = {
          file = "📁",          -- Icon for file indicator
          clean = "✓",          -- Icon for clean file (no notes)
        },
        colors = {
          vulnerable = "red",   -- Color for vulnerable file status
          todo = "yellow",      -- Color for todo file status
          safe = "green",       -- Color for safe file status
          clean = "green",      -- Color for clean file status
        },
      },
      line_notes = {
        enabled = true,          -- Enable current line notes component
        format = "%{line_icon} %{state_icon}%{cwe}",
        icons = {
          line = "📍",          -- Icon for line indicator
          vulnerable = "🔴",    -- Icon for vulnerable state on current line
          not_vulnerable = "✅", -- Icon for safe state on current line
          todo = "📝",          -- Icon for todo state on current line
        },
        colors = {
          vulnerable = "red",   -- Color for vulnerable line notes
          not_vulnerable = "green", -- Color for safe line notes
          todo = "yellow",      -- Color for todo line notes
        },
      },
      collaboration = {
        enabled = true,          -- Enable collaboration status component
        format = "%{status_icon} %{mode}",
        icons = {
          online = "👥",        -- Icon for online collaboration
          offline = "📴",       -- Icon for offline mode
          ["local"] = "👤",     -- Icon for local mode
        },
        colors = {
          online = "green",     -- Color for online collaboration
          offline = "yellow",   -- Color for offline mode
          ["local"] = "blue",   -- Color for local mode
        },
      },
    },
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

> [!NOTE]
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

| `<Plug>` Mapping              | Description                           | Function             |
| ----------------------------- | ------------------------------------- | -------------------- |
| `<Plug>(ScrewCreateNote)`     | Create security note at cursor        | Core note creation   |
| `<Plug>(ScrewEditNote)`       | Edit existing note                    | Note modification    |
| `<Plug>(ScrewDeleteNote)`     | Delete existing note                  | Note removal         |
| `<Plug>(ScrewReplyToNote)`    | Reply to existing note                | Threaded discussions |
| `<Plug>(ScrewViewLineNotes)`  | View notes for current line           | Line-specific notes  |
| `<Plug>(ScrewViewFileNotes)`  | View notes for current file           | File-wide notes      |
| `<Plug>(ScrewViewAllNotes)`   | View all project notes                | Project overview     |
| `<Plug>(ScrewExportMarkdown)` | Export to Markdown                    | Quick export         |
| `<Plug>(ScrewJumpNext)`       | Jump to next note in current file     | Navigation           |
| `<Plug>(ScrewJumpPrev)`       | Jump to previous note in current file | Navigation           |
| `<Plug>(ScrewStats)`          | Show project statistics               | Analytics            |

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

## :keyboard: Keymap Reference

This comprehensive reference shows all available `<Plug>` mappings organized by function. For setup examples and configuration patterns, see the [Custom keymaps](#custom-keymaps) section above.

### Core Note Management

| Command                    | Description                                   | Example Mapping                                                 |
| -------------------------- | --------------------------------------------- | --------------------------------------------------------------- |
| `<Plug>(ScrewCreateNote)`  | Create security note at cursor position       | `vim.keymap.set("n", "<leader>sn", "<Plug>(ScrewCreateNote)")`  |
| `<Plug>(ScrewEditNote)`    | Edit existing note on current line            | `vim.keymap.set("n", "<leader>se", "<Plug>(ScrewEditNote)")`    |
| `<Plug>(ScrewDeleteNote)`  | Delete existing note on current line          | `vim.keymap.set("n", "<leader>sd", "<Plug>(ScrewDeleteNote)")`  |
| `<Plug>(ScrewReplyToNote)` | Reply to existing note (threaded discussions) | `vim.keymap.set("n", "<leader>sr", "<Plug>(ScrewReplyToNote)")` |

### Note Viewing & Navigation

| Command                      | Description                                    | Example Mapping                                                   |
| ---------------------------- | ---------------------------------------------- | ----------------------------------------------------------------- |
| `<Plug>(ScrewViewLineNotes)` | View notes for current line in float window    | `vim.keymap.set("n", "<leader>sv", "<Plug>(ScrewViewLineNotes)")` |
| `<Plug>(ScrewViewFileNotes)` | View all notes for current file                | `vim.keymap.set("n", "<leader>sf", "<Plug>(ScrewViewFileNotes)")` |
| `<Plug>(ScrewViewAllNotes)`  | View all project notes in quickfix list        | `vim.keymap.set("n", "<leader>sa", "<Plug>(ScrewViewAllNotes)")`  |
| `<Plug>(ScrewJumpNext)`      | Jump to next security note in current file     | `vim.keymap.set("n", "]s", "<Plug>(ScrewJumpNext)")`              |
| `<Plug>(ScrewJumpPrev)`      | Jump to previous security note in current file | `vim.keymap.set("n", "[s", "<Plug>(ScrewJumpPrev)")`              |

### Export & Analytics

| Command                       | Description                         | Example Mapping                                                    |
| ----------------------------- | ----------------------------------- | ------------------------------------------------------------------ |
| `<Plug>(ScrewExportMarkdown)` | Export notes to Markdown format     | `vim.keymap.set("n", "<leader>sx", "<Plug>(ScrewExportMarkdown)")` |
| `<Plug>(ScrewStats)`          | Show project statistics and summary | `vim.keymap.set("n", "<leader>ss", "<Plug>(ScrewStats)")`          |

## :art: Available Highlight Groups

screw.nvim provides comprehensive syntax highlighting customization through highlight groups. All highlight groups can be customized to match your colorscheme and preferences.

### Sign Column Highlights

| Highlight Group                  | Purpose                                     | Example Customization                                                          |
| -------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------ |
| `ScrewSignVulnerable`            | Sign color for vulnerable findings          | `vim.api.nvim_set_hl(0, "ScrewSignVulnerable", { fg = "#ff4444" })`            |
| `ScrewSignNotVulnerable`         | Sign color for safe/reviewed code           | `vim.api.nvim_set_hl(0, "ScrewSignNotVulnerable", { fg = "#44ff44" })`         |
| `ScrewSignTodo`                  | Sign color for todo/investigation items     | `vim.api.nvim_set_hl(0, "ScrewSignTodo", { fg = "#ffaa00" })`                  |
| `ScrewSignVulnerableImported`    | Sign color for imported vulnerable findings | `vim.api.nvim_set_hl(0, "ScrewSignVulnerableImported", { fg = "#ff6666" })`    |
| `ScrewSignNotVulnerableImported` | Sign color for imported safe findings       | `vim.api.nvim_set_hl(0, "ScrewSignNotVulnerableImported", { fg = "#66ff66" })` |
| `ScrewSignTodoImported`          | Sign color for imported todo items          | `vim.api.nvim_set_hl(0, "ScrewSignTodoImported", { fg = "#ffcc44" })`          |

### Float Window UI Highlights

| Highlight Group      | Purpose                                 | Example Customization                                                     |
| -------------------- | --------------------------------------- | ------------------------------------------------------------------------- |
| `ScrewNoteMarker`    | Note markers and decorations in UI      | `vim.api.nvim_set_hl(0, "ScrewNoteMarker", { link = "DiagnosticInfo" })`  |
| `ScrewVulnerable`    | Text styling for vulnerable notes in UI | `vim.api.nvim_set_hl(0, "ScrewVulnerable", { link = "DiagnosticError" })` |
| `ScrewNotVulnerable` | Text styling for safe notes in UI       | `vim.api.nvim_set_hl(0, "ScrewNotVulnerable", { link = "DiagnosticOk" })` |
| `ScrewTodo`          | Text styling for todo notes in UI       | `vim.api.nvim_set_hl(0, "ScrewTodo", { link = "DiagnosticWarn" })`        |
| `ScrewFieldTitle`    | Field labels and titles in note forms   | `vim.api.nvim_set_hl(0, "ScrewFieldTitle", { link = "Title" })`           |
| `ScrewFieldInfo`     | Field information and metadata          | `vim.api.nvim_set_hl(0, "ScrewFieldInfo", { link = "Comment" })`          |

### Configuration-Based Highlighting

All highlight groups can also be configured through the plugin's configuration system:

```lua
{
  "h0pes/screw.nvim",
  opts = {
    ui = {
      highlights = {
        note_marker = "DiagnosticInfo",      -- Maps to ScrewNoteMarker
        vulnerable = "DiagnosticError",       -- Maps to ScrewVulnerable
        not_vulnerable = "DiagnosticOk",      -- Maps to ScrewNotVulnerable
        todo = "DiagnosticWarn",             -- Maps to ScrewTodo
        field_title = "Title",               -- Maps to ScrewFieldTitle
        field_info = "Comment",              -- Maps to ScrewFieldInfo
      },
    },
    signs = {
      colors = {
        vulnerable = "#ff4444",              -- ScrewSignVulnerable foreground
        not_vulnerable = "#44ff44",          -- ScrewSignNotVulnerable foreground
        todo = "#ffaa00",                    -- ScrewSignTodo foreground
        vulnerable_imported = "#ff6666",     -- ScrewSignVulnerableImported foreground
        not_vulnerable_imported = "#66ff66", -- ScrewSignNotVulnerableImported foreground
        todo_imported = "#ffcc44",           -- ScrewSignTodoImported foreground
      },
    },
  }
}
```

## :computer: Commands

All commands are scoped under `:Screw` with intelligent tab completion and file path assistance:

### Core Commands

| Command                                    | Description                                            | Example                              |
| ------------------------------------------ | ------------------------------------------------------ | ------------------------------------ |
| `:Screw note add`                          | Create note at cursor position                         | `:Screw note add`                    |
| `:Screw note edit`                         | Edit existing note                                     | `:Screw note edit`                   |
| `:Screw note delete [line\|file\|project]` | Delete existing note(s)                                | `:Screw note delete line`            |
| `:Screw note reply`                        | Add reply to existing note                             | `:Screw note reply`                  |
| `:Screw note view {line\|file\|project}`   | View notes by scope                                    | `:Screw note view line`              |
| `:Screw export {format} [path]`            | Export to Markdown, csv, json, sarif a security report | `:Screw export sarif report.sarif`   |
| `:Screw import {sarif} <path>`             | Import SAST results in SARIF format                    | `:Screw import sarif results.sarif` |
| `:Screw jump {next\|prev} [keywords...]`   | Jump to next/prev note                                 | `:Screw jump next FIXME BUG`         |
| `:Screw search [options]`                  | Search notes with Telescope                            | `:Screw search --state vulnerable`   |
| `:Screw stats`                             | Display project statistics                             | `:Screw stats`                       |

### Command Details

#### :memo: Note Management

```vim
" Create a new security note at cursor position
:Screw note add

" Edit an existing note (shows selection if multiple notes on line)
:Screw note edit

" Delete an existing note (shows selection if multiple notes on line)
:Screw note delete
:Screw note delete line " same as previous command

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
:Screw note view project
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

#### :inbox_tray: Import from AST Tools

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
:Screw note view <Tab>          " → line, file, project
:Screw note delete <Tab>        " → line, file, project
:Screw export <Tab>             " → markdown, json, csv, sarif
:Screw export sarif <Tab>       " → file path completion
:Screw import <Tab>             " → sarif
:Screw import sarif <Tab>     " → file path completion
:Screw jump <Tab>               " → next, prev
:Screw jump next <Tab>          " → VULNERABLE, FIXME, BUG, TODO, etc.
:Screw search <Tab>             " → --file, --project, --state, --severity, --cwe, --author, --keywords
```

## :chart_with_upwards_trend: Lualine Integration

**Display security notes information directly in your statusline** with comprehensive customization options for security-focused workflows.

### :sparkles: Available Components

**1. Project Summary (`screw_summary`)**

- Shows **project-wide** notes count with breakdown by state
- Format: "🔍 15 🔴5 📝3 ✅7" (total, vulnerable, todo, safe across entire codebase)
- Real-time updates as notes are added/modified anywhere in the project

**2. Current File Status (`screw_file_status`)**

- Shows note count breakdown for **currently open file only**
- Format: "📁 3 🔴1 📝1 ✅1" (total, vulnerable, todo, safe in current file)
- Shows "✓ clean" when current file has no notes

**3. Current Line Indicator (`screw_line_notes`)**

- Shows note details when cursor is on line with security notes
- Format: "🔴 CWE-79 high" (state icon, CWE, severity for current line)
- Only visible when cursor is positioned on a line with notes

**4. Collaboration Status (`screw_collab`)**

- Shows collaboration mode status
- Format: "👥 Online" or "👤 Local"
- Real-time connection status updates

### :gear: Setup

**Basic Configuration:**

```lua
{
  "h0pes/screw.nvim",
  opts = {
    lualine = {
      enabled = true,  -- Enable lualine integration
    }
  }
}
```

**Lualine Configuration:**

Screw.nvim components work automatically once the plugin is loaded. Here are several ways to integrate them into your lualine setup:

**Method 1: Safe component loading (Recommended)**

```lua
-- Helper function to safely get screw components
local function get_screw_component(component_name)
  return function()
    -- Only proceed if screw is already loaded (don't trigger loading)
    if not package.loaded["screw"] then
      return ""
    end

    local screw = require("screw")
    local components = screw.get_lualine_components()
    if components[component_name] then
      return components[component_name]()
    end
    return ""
  end
end

require('lualine').setup {
  sections = {
    lualine_b = {
      {
        get_screw_component("screw_file_status"),
        color = "ScrewFileStatus", -- Optional custom color
      },
    },
    lualine_x = {
      {
        get_screw_component("screw_collab"),
        color = "ScrewCollab",
      },
      {
        get_screw_component("screw_summary"),
        color = "ScrewSummary",
      },
    },
    lualine_y = {
      {
        get_screw_component("screw_line_notes"),
        color = "ScrewVulnerable",
      },
    },
  }
}
```

**Method 2: Direct string components (if screw is always loaded)**

```lua
require('lualine').setup {
  sections = {
    lualine_b = { 'screw_file_status' },
    lualine_x = { 'screw_summary', 'screw_collab' },
    lualine_y = { 'screw_line_notes' },
  }
}
```

**Method 3: Custom highlight groups**

You can define custom highlight groups for better visual integration:

```lua
-- Define custom highlight groups for screw components
vim.api.nvim_set_hl(0, "ScrewSummary", { fg = "#a488e4", bg = "NONE" }) -- Purple for project summary
vim.api.nvim_set_hl(0, "ScrewFileStatus", { fg = "#b65f9c", bg = "NONE" }) -- Magenta for current file
vim.api.nvim_set_hl(0, "ScrewVulnerable", { fg = "#bc7ec3", bg = "NONE" }) -- Pink for vulnerable
vim.api.nvim_set_hl(0, "ScrewTodo", { fg = "#a3a3ed", bg = "NONE" }) -- Light blue for todo
vim.api.nvim_set_hl(0, "ScrewSafe", { fg = "#6f7adc", bg = "NONE" }) -- Green-blue for safe
vim.api.nvim_set_hl(0, "ScrewCollab", { fg = "#39c5cf", bg = "NONE" }) -- Cyan for collaboration

-- Then use them in your lualine setup
require('lualine').setup {
  sections = {
    lualine_b = {
      {
        get_screw_component("screw_file_status"),
        color = "ScrewFileStatus",
      },
    },
    lualine_x = {
      {
        get_screw_component("screw_collab"),
        color = "ScrewCollab",
      },
      {
        get_screw_component("screw_summary"),
        color = "ScrewSummary",
      },
    },
    lualine_y = {
      {
        get_screw_component("screw_line_notes"),
        color = "ScrewVulnerable",
      },
    },
  }
}
```

### :art: Customization

**Complete Component Customization:**

```lua
{
  "h0pes/screw.nvim",
  opts = {
    lualine = {
      enabled = true,
      components = {
        summary = {
          enabled = true,
          format = "%{total_icon} %{total} | %{vulnerable_icon}%{vulnerable} %{todo_icon}%{todo}",
          icons = {
            total = "🔍",
            vulnerable = "🔴",
            todo = "📝",
            safe = "✅"
          },
          colors = {
            vulnerable = "red",
            todo = "yellow",
            safe = "green"
          }
        },
        file_status = {
          enabled = true,
          format = "%{file_icon} %{count} security notes",
          icons = {
            file = "📁",
            clean = "✓"
          }
        },
        line_notes = {
          enabled = true,
          format = "%{line_icon} %{state_icon}%{cwe}",
          icons = {
            line = "📍",
            vulnerable = "🔴",
            todo = "📝"
          }
        },
        collaboration = {
          enabled = true,
          format = "%{status_icon} %{mode}",
          icons = {
            online = "👥",
            offline = "📴",
            ["local"] = "👤"
          }
        }
      }
    }
  }
}
```

### :bulb: Usage Examples

**Minimal Security Dashboard:**

```lua
sections = {
  lualine_x = { 'screw_summary' }
}
```

**Comprehensive Security Statusline:**

```lua
sections = {
  lualine_b = { 'screw_file_status' },
  lualine_x = { 'screw_summary', 'screw_collab' },
  lualine_y = { 'screw_line_notes' }
}
```

**Security-Focused Layout:**

```lua
sections = {
  lualine_a = { 'mode' },
  lualine_b = { 'branch', 'screw_file_status' },
  lualine_c = { 'filename' },
  lualine_x = { 'screw_collab', 'screw_summary' },
  lualine_y = { 'screw_line_notes', 'location' },
  lualine_z = { 'progress' }
}
```

### :information_source: Component Details

**Format String Placeholders:**

_Summary Component:_

- `%{total}`, `%{vulnerable}`, `%{todo}`, `%{not_vulnerable}` - Counts
- `%{total_icon}`, `%{vulnerable_icon}`, `%{todo_icon}`, `%{safe_icon}` - Icons

_File Status Component:_

- `%{count}` - Note count, `%{state}` - File state, `%{is_clean}` - Boolean clean status
- `%{file_icon}`, `%{clean_icon}` - Icons

_Line Notes Component:_

- `%{state}`, `%{cwe}`, `%{severity}`, `%{count}` - Note properties
- `%{line_icon}`, `%{state_icon}` - Icons

_Collaboration Component:_

- `%{mode}` - Connection mode, `%{is_online}`, `%{is_local}` - Boolean status
- `%{status_icon}`, `%{online_icon}`, `%{offline_icon}`, `%{local_icon}` - Icons

### :warning: Requirements

- **lualine.nvim** - Must be installed and configured
- **Automatic detection** - Integration only loads if lualine is present
- **Disabled by default** - Must be explicitly enabled in configuration

### :mag: Troubleshooting

**Check Integration Status:**

```lua
local screw = require("screw")
local available, error = screw.check_lualine_availability()
print("Lualine integration:", available, error or "")
```

**Get Available Components:**

```lua
local components = screw.get_lualine_components()
print(vim.inspect(components))
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
  format = "sarif",
  input_path = "/tmp/semgrep-results.sarif"
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

**HTTP-powered multi-user security reviews** enabling seamless team collaboration with zero client dependencies, automatic synchronization, and enterprise-grade scalability.

### :building_construction: Architecture Overview

screw.nvim's collaboration system uses a modern **three-tier architecture**:

```
┌─────────────────┐    HTTP/JSON     ┌──────────────────┐    PostgreSQL    ┌─────────────────┐
│   screw.nvim    │◄────────────────►│  FastAPI Server │◄─────────────────►│   PostgreSQL    │
│   (Client 1)    │                  │   (Python 3.8+) │                   │    Database     │
└─────────────────┘                  │                  │                   └─────────────────┘
┌─────────────────┐    REST API      │  - Notes CRUD    │
│   screw.nvim    │◄────────────────►│  - Reply system  │
│   (Client 2)    │                  │  - Real-time     │
└─────────────────┘                  │    sync          │
┌─────────────────┐                  │  - Project mgmt  │
│   screw.nvim    │◄────────────────►│                  │
│   (Client N)    │                  └──────────────────┘
└─────────────────┘
```

**Technology Stack:**

- **Frontend**: Neovim Lua client with HTTP backend
- **API Layer**: FastAPI (Python) REST server with automatic API documentation
- **Database**: PostgreSQL 12+ with optimized schema for security notes
- **Transport**: HTTP/JSON with optional HTTPS encryption
- **Dependencies**: System curl (pre-installed), no database drivers required



https://github.com/user-attachments/assets/7ce62345-dc35-429b-9e7e-d3037e5a1486



### :rocket: Quick Setup

**1. Deploy collaboration server:**

> **📖 Complete Guide**: See [COLLABORATION.md](COLLABORATION.md) for detailed server deployment instructions

```bash
# Option 1: Automated deployment (recommended)
./deploy_server.sh

# Option 2: Manual setup with UV (ultra-fast Python package manager)
uv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
uv pip install fastapi uvicorn asyncpg pydantic python-multipart
uvicorn main:app --host 0.0.0.0 --port 3000

# Option 3: PostgreSQL database setup (if not using automated deployment)
sudo -u postgres psql -f scripts/setup_postgresql.sql
```

**2. Configure environment variables:**

```bash
# Required: API server connection
export SCREW_API_URL="http://your-server:3000/api"

# Required: User identification (choose one)
export SCREW_USER_EMAIL="analyst@company.com"  # Preferred
export SCREW_USER_ID="your-username"           # Alternative
```

**3. Enable collaboration mode:**

```lua
{
  "h0pes/screw.nvim",
  opts = {
    storage = {
      backend = "http",  -- Switch from JSON/SQLite to HTTP
    },
    collaboration = {
      enabled = true,    -- Enable collaboration features
    }
  }
}
```

### :sparkles: Key Features

- **🌐 Zero Client Dependencies** - Only requires system curl (pre-installed)
- **📡 RESTful Architecture** - FastAPI server with PostgreSQL backend
- **🔄 Automatic Synchronization** - Changes sync immediately via HTTP requests
- **📡 Graceful Offline Mode** - Continues working when server is unavailable
- **🚀 Simple Deployment** - Single Python server, no complex setup
- **👤 Author-based Permissions** - Only note authors can edit/delete their notes
- **⚡ Performance Optimized** - Local caching with smart cache invalidation
- **🔐 Production Ready** - Environment-based config, HTTPS support, comprehensive logging
- **📊 Full Feature Parity** - All import/export/search functionality works identically

### :computer: Collaboration Usage

**All standard commands work automatically in collaboration mode:**

```vim
" Standard note operations (automatically sync to server)
:Screw note add                   " Create note (syncs to server)
:Screw note edit                  " Edit note (syncs to server)
:Screw note delete                " Delete note (syncs to server)
:Screw note reply                 " Add reply (syncs to server)
:Screw note view                  " View notes (fetches latest from server)

" Search and navigation work across all team notes
:Screw search --author alice      " Find Alice's notes
:Screw search --state vulnerable  " Find team's vulnerable findings
:Screw export markdown report.md  " Export team's complete findings

" Statistics show combined team activity
:Screw stats                      " Project-wide team statistics
```

**Programmatic Collaboration API:**

```lua
local screw = require("screw")

-- Get collaboration status
local status = screw.get_collaboration_status()
print("Mode:", status.mode)                    -- "local" or "collaborative"
print("Connected:", status.realtime_sync)      -- Connection details

-- Trigger manual sync (when auto-sync isn't enough)
local success = screw.sync_notes()
if success then
  print("Manual sync completed")
end

-- Switch collaboration mode (with user confirmation)
local switched = screw.switch_collaboration_mode("local")  -- or "collaborative"

-- Force reconnection (for connection issues)
local reconnected = screw.force_reconnect()

-- Show detailed collaboration info
screw.show_collaboration_info()  -- Opens detailed status popup
```

### :gear: Advanced Configuration

```lua
-- Minimal setup - uses default local mode (JSON storage)
{
  "h0pes/screw.nvim",
  -- No opts needed - uses sensible defaults
}

-- Enable collaboration with HTTP backend
{
  "h0pes/screw.nvim",
  opts = {
    storage = {
      backend = "http",         -- Switch to HTTP backend
    },
    collaboration = {
      enabled = true,           -- Enable collaboration features
      connection_timeout = 10000, -- HTTP request timeout (ms)
      max_retries = 3,          -- Connection retry attempts
      sync_interval = 5000,     -- Auto-sync interval (ms)
    }
  }
}

-- Advanced: Custom API configuration (usually not needed)
{
  "h0pes/screw.nvim",
  opts = {
    storage = {
      backend = "http",
    },
    collaboration = {
      enabled = true,
      api_url = "https://your-secure-server.company.com:8443/api",  -- Custom URL
      user_id = "security-analyst-123",                             -- Custom user ID
      project_name = "webapp-security-review",                      -- Custom project name
    }
  }
}
```

### :warning: Environment Setup

**Required environment variables:**

```bash
# API server endpoint (required)
export SCREW_API_URL="http://your-server:3000/api"
# For production with HTTPS:
# export SCREW_API_URL="https://screw-api.company.com/api"

# User identification (required - choose one)
export SCREW_USER_EMAIL="security.analyst@company.com"  # Preferred method
# OR
export SCREW_USER_ID="analyst-username"                 # Alternative method
```

**Optional environment variables:**

```bash
# For custom project identification
export SCREW_PROJECT_NAME="my-security-review"

# For development/testing
export SCREW_DEBUG=1                    # Enable debug logging
export SCREW_HTTP_TIMEOUT=15000         # Custom timeout (milliseconds)
```

> [!TIP]
> **📖 Complete Setup Guide**: See [COLLABORATION.md](COLLABORATION.md) for detailed server deployment, database setup, Docker configuration, production hardening, and comprehensive troubleshooting.

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

## :inbox_tray: AST Integration

**Universal SARIF Import** - screw.nvim leverages the industry-standard SARIF (Static Analysis Results Interchange Format) v2.1.0 to provide seamless integration with virtually any security analysis tool.

### SARIF Format Support

**screw.nvim supports SARIF v2.1.0**, the universal standard for security tool interoperability:

```vim
" Import from any SARIF-compatible security tool
:Screw import sarif /path/to/security-findings.sarif
```

**Key Benefits:**
- **Universal compatibility** - Works with any SARIF v2.1.0 compliant tool
- **Metadata preservation** - Retains tool information, rule IDs, and CWE mappings
- **Smart collision handling** - Intelligent conflict resolution for overlapping findings
- **Visual differentiation** - Imported notes show distinct icons from native notes

### Compatible Security Tools

Any tool that exports SARIF v2.1.0 format is supported. Popular examples:

| Tool        | Language/Focus | SARIF Export Command                                    |
| ----------- | -------------- | ------------------------------------------------------- |
| **Semgrep** | Multi-language | `semgrep --config=auto --sarif --output=results.sarif` |
| **Bandit**  | Python         | `bandit -r /path/to/code -f sarif -o results.sarif`    |
| **Gosec**   | Go             | `gosec -fmt sarif -out results.sarif ./...`            |
| **SonarQube** | Multi-language | Export via API or CLI tools                            |
| **CodeQL**  | Multi-language | `codeql database analyze --format=sarif-latest`        |
| **ESLint**  | JavaScript     | `eslint --format @microsoft/eslint-formatter-sarif`    |

### Example Workflows

**Semgrep Integration:**
```bash
# Run Semgrep analysis
semgrep --config=auto --sarif --output=semgrep-findings.sarif .
```
```vim
:Screw import sarif semgrep-findings.sarif
```

**Bandit Integration (Python):**
```bash
# Run Bandit security analysis
bandit -r /path/to/python/code -f sarif -o bandit-results.sarif
```
```vim
:Screw import sarif bandit-results.sarif
```

**Multi-tool Workflow:**
```bash
# Combine findings from multiple tools
semgrep --config=auto --sarif -o semgrep.sarif .
bandit -r . -f sarif -o bandit.sarif
gosec -fmt sarif -out gosec.sarif ./...
```
```vim
:Screw import sarif semgrep.sarif
:Screw import sarif bandit.sarif
:Screw import sarif gosec.sarif
:Screw export sarif combined-security-report.sarif
```

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
- ✅ Optional plugin dependencies:
  - telescope.nvim (for advanced search functionality)
  - lualine.nvim (for statusline integration)

#### **⚙️ Configuration & Initialization**

- ✅ Plugin loading and module initialization
- ✅ User configuration validation and structure
- ✅ Configuration section completeness
- ✅ Dynamic configuration function support
- ✅ Unknown key detection and validation

#### **💾 Storage System**

- ✅ Storage backend functionality (JSON/HTTP)
- ✅ Directory creation and write permissions
- ✅ Storage file validation and integrity
- ✅ Storage statistics and metadata
- ✅ Backend initialization and connectivity

#### **🚀 Plugin Functionality**

- ✅ Core module loading (notes, UI, export, import, signs)
- ✅ Basic plugin operations testing
- ✅ Statistics generation functionality
- ✅ Command system integrity
- ✅ Signcolumn indicators functionality

#### **👥 Collaboration Features**

- ✅ Collaboration module loading and initialization
- ✅ Environment variable configuration (SCREW_API_URL, SCREW_USER_EMAIL)
- ✅ API URL format validation (HTTP/HTTPS)
- ✅ HTTP server connectivity testing (via curl)
- ✅ User identification verification

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
│   ├── config/         # Configuration management
│   ├── notes/          # Note management and storage backends
│   │   └── storage/    # Storage backends (JSON, HTTP)
│   ├── export/         # Export modules (Markdown, JSON, CSV, SARIF)
│   ├── import/         # Import modules (SARIF support)
│   └── collaboration/ # Real-time collaboration features
├── lua/telescope/       # Telescope extension integration
│   └── _extensions/    # Telescope screw extension
├── plugin/             # Plugin entry points and commands
├── doc/                # Help documentation
├── spec/               # Test suite
├── scripts/            # Development and automation scripts
└── .github/            # GitHub workflows and automation
```

## :handshake: Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

### Development workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `make test && make lint`
5. Submit a pull request

---

<div align="center">

**Star :star: this repo if you find it useful!**

[Report Issues](https://github.com/h0pes/screw.nvim/issues) • [Request Features](https://github.com/h0pes/screw.nvim/issues) • [Contribute](CONTRIBUTING.md)

</div>

## :page_facing_up: Documentation

For comprehensive documentation, see the [doc/](doc/) folder where all documentation is automatically generated by our dedicated pipeline.

## :warning: Requirements

- **Neovim** >= 0.9.0
- **curl** (usually pre-installed, for HTTP collaboration)
- **No external dependencies** for basic functionality
- **telescope.nvim** (optional, for search functionality)
- **lualine.nvim** (optional, for lualine integration)

## :memo: License

[MIT License](LICENSE) © 2024

## :heart: Acknowledgments

- Inspired by [RefactorSecurity's VSCode plugin](https://github.com/RefactorSecurity/vscode-security-notes)
- Built following [nvim-best-practices](https://github.com/nvim-neorocks/nvim-best-practices)
- Thanks to the Neovim community for excellent plugin development resources
