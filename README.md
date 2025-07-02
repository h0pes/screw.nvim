# Installation
<!-- TODO: (you) - Adjust and add your dependencies as needed here -->
- [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "h0pes/screw.nvim",
    dependencies = { "h0pes/mega.cmdparse", "ColinKennedy/mega.logging" },
    -- TODO: (you) - Make sure your first release matches v1.0.0 so it auto-releases!
    version = "v1.*",
}
```


# Configuration
(These are default values)

<!-- TODO: (you) - Remove / Add / Adjust your configuration here -->

- [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "h0pes/screw.nvim",
    config = function()
        vim.g.screw_configuration = {
            commands = {
                goodnight_moon = { read = { phrase = "A good book" } },
                hello_world = {
                    say = { ["repeat"] = 1, style = "lowercase" },
                },
            },
            logging = {
                level = "info",
                use_console = false,
                use_file = false,
            },
            tools = {
                lualine = {
                    arbitrary_thing = {
                        color = "Visual",
                        text = " Arbitrary Thing",
                    },
                    copy_logs = {
                        color = "Comment",
                        text = "󰈔 Copy Logs",
                    },
                    goodnight_moon = {
                        color = "Question",
                        text = " Goodnight moon",
                    },
                    hello_world = {
                        color = "Title",
                        text = " Hello, World!",
                    },
                },
                telescope = {
                    goodnight_moon = {
                        { "Foo Book", "Author A" },
                        { "Bar Book Title", "John Doe" },
                        { "Fizz Drink", "Some Name" },
                        { "Buzz Bee", "Cool Person" },
                    },
                    hello_world = { "Hi there!", "Hello, Sailor!", "What's up, doc?" },
                },
            },
        }
    end
}
```


## Lualine

<!-- TODO: (you) - Remove this is you do not want lualine -->

> Note: You can customize lualine colors here or using
> `vim.g.screw_configuration`.

[lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)
```lua
require("lualine").setup {
    sections = {
        lualine_y = {
            -- ... Your other configuration ...
            {
                "screw",
                -- NOTE: These will override default values
                -- display = {
                --     goodnight_moon = {color={fg="#FFFFFF"}, text="Custom message 1"}},
                --     hello_world = {color={fg="#333333"}, text="Custom message 2"},
                -- },
            },
        }
    }
}
```


## Telescope

<!-- TODO: (you) - Remove this is you do not want telescope -->

> Note: You can customize telescope colors here or using
> `vim.g.screw_configuration`.

[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
```lua
{
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    config = function()
        -- ... Your other configuration ...
        require("telescope").load_extension("screw")
    end,
    dependencies = {
        "h0pes/screw.nvim",
        "nvim-lua/plenary.nvim",
    },
    version = "0.1.*",
},
```


### Colors
This plugin provides two default highlights

- `screwTelescopeEntry`
- `screwTelescopeSecondary`

Both come with default colors that should look nice. If you want to change them, here's how:
```lua
vim.api.nvim_set_hl(0, "screwTelescopeEntry", {link="Statement"})
vim.api.nvim_set_hl(0, "screwTelescopeSecondary", {link="Question"})
```


# Commands
Here are some example commands:

<!-- TODO: (you) - You'll probably want to change all this or remove it. See -->
<!-- plugin/screw.lua for details. -->

```vim
" A typical subcommand
:screw hello-world say phrase "Hello, World!" " How are you?"
:screw hello-world say phrase "Hello, World!" --repeat=2 --style=lowercase

" An example of a flag this repeatable and 3 flags, -a, -b, -c, as one dash
:screw arbitrary-thing -vvv -abc -f

" Separate commands with completely separate, flexible APIs
:screw goodnight-moon count-sheep 42
:screw goodnight-moon read "a book"
:screw goodnight-moon sleep -z -z -z
```


# Tests
## Initialization
Run this line once before calling any `busted` command

```sh
eval $(luarocks path --lua-version 5.1 --bin)
```


## Running
Run all tests
```sh
# Using the package manager
luarocks test --test-type busted
# Or manually
busted .
# Or with Make
make test
```

Run test based on tags
```sh
busted . --tags=simple
```


# Coverage
Making sure that your plugin is well tested is important.
`screw.nvim` can generate a per-line breakdown of exactly where
your code is lacking tests using [LuaCov](https://luarocks.org/modules/mpeterv/luacov).


## Setup
Make sure to install all dependencies for the unittests + coverage reporter if
you have not installed them already.

```sh
luarocks install busted --local
luarocks install luacov --local
luarocks install luacov-multiple --local
```


## Running
```sh
make coverage-html
```

This will generate a `luacov.stats.out` & `luacov_html/` directory.


## Viewing
```sh
(cd luacov_html && python -m http.server)
```

If it worked, you should see a message like
`"Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000) ..."`
Open `http://0.0.0.0:8000` in a browser like
[Firefox](https://www.mozilla.org/en-US/firefox) and you should see a view like this:

![Image](https://github.com/user-attachments/assets/e5b30df8-036a-4886-81b9-affbf5c9e32a)

Just navigate down a few folders until you get to a .lua file and you'll see a breakdown
of your line coverage like this:

![Image](https://github.com/user-attachments/assets/c5420b16-4be7-4177-92c7-01af0b418816)



# Tracking Updates
See [doc/news.txt](doc/news.txt) for updates.

You can watch this plugin for changes by adding this URL to your RSS feed:
```
https://github.com/h0pes/screw.nvim/commits/main/doc/news.txt.atom
```


# Other Plugins
This template is full of various features. But if your plugin is only meant to
be a simple plugin and you don't want the bells and whistles that this template
provides, consider instead using
[nvim-screw](https://github.com/ellisonleao/nvim-plugin-template)
