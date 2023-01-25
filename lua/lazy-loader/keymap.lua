local M = {}

local fn = vim.fn
local api = vim.api

local plugin_loader = require("lazy-loader.loader").plugin_loader

local function set_key(key, plugin)
	vim.keymap.set(key.mode, key.bind, function()
		-- NOTE:Important: need to delete this map before the plugin loading because now the mappings
		-- for plugin will be loaded
		vim.keymap.del(key.mode, key.bind)
		plugin_loader(plugin)

		local extra = ""
		while true do
			local c = fn.getchar(0)
			if c == 0 then
				break
			end
			extra = extra .. fn.nr2char(c)
		end

		local prefix = vim.v.count ~= 0 and vim.v.count or ""
		prefix = prefix .. "\"" .. vim.v.register
		if fn.mode("full") == "no" then
			if vim.v.operator == "c" then
				prefix = "" .. prefix
			end
			prefix = prefix .. vim.v.operator
		end

		fn.feedkeys(prefix, "n")

		local escaped_keys = api.nvim_replace_termcodes(key.bind .. extra, true, true, true)
		api.nvim_feedkeys(escaped_keys, "m", true)
	end, key.opts or { noremap = true, silent = true })
end

function M.keymap_register(plugin_tbl)
	local plugin = vim.deepcopy(plugin_tbl)
	-- only need to send plugin information no need for sending registers information
	plugin.keymap = nil

	local keymap = plugin_tbl.keymap
	if keymap and keymap.keys then
		local keys = keymap.keys
		for _, k in pairs(keys) do
			local mode = "n"
			local bind = k
			if type(k) == "table" then
				mode = k[1]
				bind = k[2]
			end
			local keybind = { mode = mode, bind = bind, opts = { noremap = true, silent = true } }
			set_key(keybind, plugin)
		end
	end
end

return M
