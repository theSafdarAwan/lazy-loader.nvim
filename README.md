### Purpose of this plugin.

This plugin allows to get a little bit more lazy loading power then you had
before. See the examples to get a sense of what it does.

#### load function

This plugin exposes you a function called _load_ to which you can pass your
plugin table that will be lazy loaded. According to your config for that plugin.

### Available configuration

```lua
{
    name = "foo",
    on_load = {
        reload_buffer = true,
        config = function()
            -- require your config modules here
        end,
    },
    keymap = {
            keys = { "n", "[n" }
        },
    autocmd = {
        ft = "foo", -- file type in which this plugin should be loaded
        -- TODO: wtf is this
        keymap = {
                { "n", "<leader>ff" },
                { "n", "<leader>tt" },
        },
    },
}
```

- `name`<br>
  This key lets you specify the name of the plugin.<br>
  Ex. `name = "markdown-preview.nvim"`

- `on_load`<br>
  This key lets you specify a table for with these keys.
  - `realod_buffer`<br>
    this key allows you to reload buffer after the plugin is loaded important for
    plugins like _markdown-preview.nvim_ which if lazy loaded don't give you
    access to the commands liek _MarkdownPreview_ but if you reload the buffer
    it will be loaded properly.

###### Examples

- Markdown Preview Plugin

```lua
local md_preview = {
    name = "markdown-preview.nvim",
    on_load = {
        reload_buffer = true,
        config = function()
            require("safdar.setup.writing.markdown-preview.config").config()
        end,
    },
    autocmd = {
        ft = "markdown",
        keymap = {
            keys = { "<leader>mp" },
        },
    },
}
require("lazy-loader").load(md_preview)
```
