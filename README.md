I have migrated to the [lazy.nvim](https://github.com/folke/lazy.nvim.git/)

this Plugin won't be continued

### Purpose of this plugin.

> NOTE: This plugin can only be used with [packer.nvim](https://github.com/wbthomason/packer.nvim).

This plugin allows to get a little bit more lazy loading power than you had
before with packer.

> NOTE: This Plugin was actually not meant to be a plugin but just help me reduce
> the time it took neovim to load. Which was pretty cool thing but after i
> realized that this could be used by some other people like me who want to
> reduce the time neovim takes to load i extracted this to its own plugin.

I have cut down upto 70% of loading time with this plugin. I hope this also helps
you.

#### load function

This plugin exposes you a function called `load` to which you can pass your
plugin table that will be lazy loaded. According to your config for that plugin.

There are two ways to load plugins i call these loaders.

- autocmd<br>
  This loader uses the `vim.api.nvim_create_autocmd` in its core. And allows
  you to load plugin in just a few lines rather than you having to write this
  autocmd every time.
- keymap<br>
  This loader lets you load plugin through a keymap or multiple keymaps.
  > You can also add this keymap loader inside of the autocmd loader. Which i will
  > discuss in the examples.

### Configuration

```lua
{
    -- plugin name
    name = "foo",
    -- load this plugin after this plugin
    after = "", -- string
    -- table or string: add plugins that the plugin requires which should be
    -- loaded before this plugin
    requires = {}, -- table or a string
    -- after loading the plugin do these things
    on_load = {
        -- to reload buffer after loading plugin
        reload_buffer = true,
        -- plugin configuration loading
        config = function()
            -- require your config modules here
        end,
    },
    -- this loader allows you to load plugin using the keymaps
    keymap = {
            -- this table for now just accepts keys this keys
            -- table you can add table
            keys = {
                { { "n", "v" }, "<leader>ff" },
                { "n", "<leader>tt" },
            }
        },
    -- You can load your plugin with autocmd loader with these methods:
    -- 1: events
    -- 2: filetype
    -- 3: file extensions
    -- 4: keymap -> this helps in case you don't want maps to be added before you
    -- go to that file type or that your specified event occurs, etc
    autocmd = {
        -- string or table: you can specify the events for the autocmd or you can
        -- leave this if you are using the ft or ft_ext
        events = {}
         -- string or table: file type in which this plugin should be loaded
        ft = "foo",
         -- table or string: file extension like for *.lua add lua
         -- this is a very important feature because if you want to lazy load the
         -- plugins like norg then you won't have the file type for the norg
         -- files because norg plugin set's the file type for the norg fiels
         -- and the norg plugin won't be loaded.
        ft_ext = "md",
        -- same as the keymap loader
        keymap = {},
        -- a callback function that can be used as a conditional see the gitsigns example
        callback = function()
        end
    },
}
```

I can only describe the power of this plugin only by giving you some examples.

###### Examples

- cmp-dictionary<br>
  This plugin will only be loaded in `markdown`, `html` and `norg` files.

```lua
local cmp_dictionary = {
    name = "cmp-dictionary",
    autocmd = {
        -- you can use file's extensions
        ft_ext = { "md", "html", "norg" },
        -- or if you want to use the file type
        ft = { "markdown", "html", "norg" },
        events = "CursorMoved",
    },
    on_load = {
        config = function()
            require("cmp_dictionary").setup()
        end,
    },
}
require("lazy-loader").load(cmp_dictionary)
```

- Markdown Preview<br>
  Now here we you have to understand something, that this plugin takes `on_load`
  table config and than loads it according to the loader config that you specified. Like
  in this case this plugin won't be loaded in the markdown file type, instead it
  will add those mapping from `autocmd.keymap.keys` in the `markdown` file type and after
  you press `<leader>mp` than only this plugin will loaded the `markdown-preview.nvim`.

```lua
local md_preview = {
    name = "markdown-preview.nvim",
    on_load = {
        -- this is very important becuase markdown-preview.nvim won't be loaded
        -- properly it will be loaded but you won't be able to access it from
        -- command line with these command's:
        -- :MarkdownPreview
        -- :MarkdownPreviewToggle
        -- :MarkdownPreviewStop
        -- so to load this you need to reload the buffer.
        reload_buffer = true,
        config = function()
            local g = vim.g
            g.mkdp_refresh_slow = 1
            g.mkdp_browser = "firefox"
            g.mkdp_echo_preview_url = 1
            g.mkdp_filetypes = { "markdown" }
        end,
    },
    autocmd = {
        ft_ext = "md",
        -- OR
        ft = "markdown",
        keymap = {
            keys = { "<leader>mp" },
        },
    },
}
require("lazy-loader").load(md_preview)
```

- norg<br>
  This plugin will only be loaded in `norg` files or using the keymap `gtc` which
  captures the todo(NOTE: at the moment norg removed this feature so this keymap
  won't be available but you get the idea how to use keymap and autocmd both).

```lua
local lazy_load = {
    name = "neorg",
    on_load = {
        config = function()
            -- your config
        end,
    },
    -- NOTE: the :Neorg capture has been removed so this keymap won't work
    -- keymap = {
    --     keys = { "gtc" },
    -- },
    autocmd = {
        ft_ext = "norg",
    },
}
require("lazy-loader").load(lazy_load)
```

- gitsigns<br>
  This plugin will only be loaded if the autocmd callback returns true else it
  will run on Every `BufRead` event until the extension gets loaded.
  **NvChad** does the same as this function.

```lua
local gitsigns = {
    name = "gitsigns.nvim",
    on_load = {
        config = function()
            -- load config from here
        end,
    },
    autocmd = {
        event = "BufRead",
        callback = function()
            -- this variable is just for my status line which changes the git
            -- git status
            vim.g.__git_is_ok = false
            -- if this commands returns true the next guard will become true and
            -- the plugin will be loaded
            vim.fn.system("git -C " .. vim.fn.expand("%:p:h") .. " rev-parse")
            if vim.v.shell_error == 0 then
                vim.g.__git_is_ok = true
                return true
            end
        end,
    },
}
require("lazy-loader").load(gitsigns)
```

For more examples you can look into my personal config [here](https://github.com/TheSafdarAwan/nvim_conf/tree/master/lua/safdar/setup).

#### Adding to the packer.nvim config

To lazy load with this plugin you have to add the `opt = true` key to the packer
plugin table. After that the config for the `lazy-loader.nvim` in the `setup`
function of the `packer.nvim` don't add it to the `config` function it won't be
loaded.

#### Draw Backs

The only draw back of using this plugin is that you can't use the `run` key in
the packer config table anymore in the norg file type. It gives error. Which i
will work on a bit latter.
