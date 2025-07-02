--- A collection of types to be included / used in other Lua files.
---
--- These types are either required by the Lua API or required for the normal
--- operation of this Lua plugin.
---

---@class screw.Configuration
---    The user's customizations for this plugin.
---@field commands screw.ConfigurationCommands?
---    Customize the fallback behavior of all `:screw` commands.
---@field logging screw.LoggingConfiguration?
---    Control how and which logs print to file / Neovim.
---@field tools screw.ConfigurationTools?
---    Optional third-party tool integrations.

---@class screw.ConfigurationCommands
---    Customize the fallback behavior of all `:screw` commands.
---@field goodnight_moon screw.ConfigurationGoodnightMoon?
---    The default values when a user calls `:screw goodnight-moon`.
---@field hello_world screw.ConfigurationHelloWorld?
---    The default values when a user calls `:screw hello-world`.

---@class screw.ConfigurationGoodnightMoon
---    The default values when a user calls `:screw goodnight-moon`.
---@field read screw.ConfigurationGoodnightMoonRead?
---    The default values when a user calls `:screw goodnight-moon read`.

---@class screw.LoggingConfiguration
---    Control whether or not logging is printed to the console or to disk.
---@field level (
---    | "trace"
---    | "debug"
---    | "info"
---    | "warn" | "error"
---    | "fatal"
---    | vim.log.levels.DEBUG
---    | vim.log.levels.ERROR
---    | vim.log.levels.INFO
---    | vim.log.levels.TRACE
---    | vim.log.levels.WARN)?
---    Any messages above this level will be logged.
---@field use_console boolean?
---    Should print the output to neovim while running. Warning: This is very
---    spammy. You probably don't want to enable this unless you have to.
---@field use_file boolean?
---    Should write to a file.
---@field output_path string?
---    The default path on-disk where log files will be written to.
---    Defaults to "/home/selecaoone/.local/share/nvim/plugin_name.log".

---@class screw.ConfigurationGoodnightMoonRead
---    The default values when a user calls `:screw goodnight-moon read`.
---@field phrase string
---    The book to read if no book is given by the user.

---@class screw.ConfigurationHelloWorld
---    The default values when a user calls `:screw hello-world`.
---@field say screw.ConfigurationHelloWorldSay?
---    The default values when a user calls `:screw hello-world say`.

---@class screw.ConfigurationHelloWorldSay
---    The default values when a user calls `:screw hello-world say`.
---@field repeat number
---    A 1-or-more value. When 1, the phrase is said once. When 2+, the phrase
---    is repeated that many times.
---@field style "lowercase" | "uppercase"
---    Control how the text is displayed. e.g. "uppercase" changes "hello" to "HELLO".

---@class screw.ConfigurationTools
---    Optional third-party tool integrations.
---@field lualine screw.ConfigurationToolsLualine?
---    A Vim statusline replacement that will show the command that the user just ran.

---@alias screw.ConfigurationToolsLualine table<string, plugin_template.ConfigurationToolsLualineData>
---    Each runnable command and its display text.

---@class screw.ConfigurationToolsLualineData
---    The display values that will be used when a specific `screw`
---    command runs.
---@diagnostic disable-next-line: undefined-doc-name
---@field color vim.api.keyset.highlight?
---    The foreground/background color to use for the Lualine status.
---@field prefix string?
---    The text to display in lualine.
