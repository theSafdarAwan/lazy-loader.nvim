local M = {}

local vim = vim
----------------------------------------------------------------------
--                        lazy loader utils                         --
----------------------------------------------------------------------
local packer = require("packer")
local packer_plugins = _G.packer_plugins

----------------------------------------------------------------------
--                          Plugin Loader                           --
----------------------------------------------------------------------
local function load_plugin(plugin)
	if packer_plugins[plugin.name] and not packer_plugins[plugin.name].enable then
		-- load the user configuration before loading plugin
		if plugin.before_load and plugin.before_load.config then
			plugin.before_load.config()
		end
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end

		-- add the package this is important else you won't be able to
		-- execute the command from command line for this plugin's you lazy loaded
		vim.cmd("silent! packadd " .. plugin.name)
		packer.loader(plugin.name)
	elseif packer_plugins[plugin.name] and packer_plugins[plugin.name].enable then
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end
	else
		return
	end

	-- load the user configuration after loading plugin
	if plugin.on_load and plugin.on_load.config then
		plugin.on_load.config()
	end

	-- NOTE: this is for user only if the plugin they are trying to load is giving some problems
	if plugin.on_load and plugin.on_load.event then
		-- execute event if provided in the on_load.event
		vim.schedule(function()
			vim.cmd("silent! do " .. plugin.on_load.event)
		end)
	else
		vim.schedule(function()
			-- a little trick to trigger the reload the buffer after the plugin is loaded
			vim.cmd("silent! do BufEnter")
		end)
	end
end

local api = vim.api
local events = { "BufRead", "BufWinEnter", "BufNewFile" }

----------------------------------------------------------------------
--                         Autocmd Register                         --
----------------------------------------------------------------------
function M.autocmd_register(plugin)
	local autocmd = plugin.autocmd
	-- pattern for the autocmd if provided
	local pattern = nil
	if autocmd.ft then
		-- filetype as a pattern
		pattern = plugin.ft
	elseif autocmd.ft_ext then
		-- filetype extension can also be used as a pattern
		pattern = "*." .. plugin.ft_ext
	end

	api.nvim_create_autocmd(plugin.events or plugin.event or events, {
		group = api.nvim_create_augroup("lazy_load_" .. plugin.name, { clear = true }),
		pattern = pattern,
		callback = function()
			if autocmd and autocmd.keymap then
				-- need to delete the augroup before registering a mapping to load the plugin
				vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)

				-- convert the autocmd plugin tbl to keymap_tbl
				local keymap_tbl = vim.deepcopy(plugin)
				keymap_tbl.keymap = autocmd.keymap
				-- need to delete the augroup for this plugin
				keymap_tbl.del_augroup = true
				keymap_tbl.autocmd = nil
				M.keymap_register(keymap_tbl)
			else
				load_plugin(plugin)
			end
		end,
	})
end

----------------------------------------------------------------------
--                          Keymap Loader                           --
----------------------------------------------------------------------
local function set_key(key, plugin)
	vim.keymap.set(key.mode, key.bind, function()
		-- Important: need to delete this map before the plugin loading because now the mappings
		-- for plugin will be loaded
		vim.keymap.del(key.mode, key.bind)

		load_plugin(plugin)
		if plugin.on_load.cmd then
			-- need to schedule_wrap this else some cmds will be executed before even the
			-- plugin is loaded properly
			vim.schedule_wrap(function()
				vim.cmd(plugin.on_load.cmd)
			end)
		end

		local extra = ""
		while true do
			local c = vim.fn.getchar(0)
			if c == 0 then
				break
			end
			extra = extra .. vim.fn.nr2char(c)
		end

		local prefix = vim.v.count ~= 0 and vim.v.count or ""
		prefix = prefix .. "\"" .. vim.v.register
		if vim.fn.mode("full") == "no" then
			if vim.v.operator == "c" then
				prefix = "" .. prefix
			end
			prefix = prefix .. vim.v.operator
		end

		vim.fn.feedkeys(prefix, "n")

		local escaped_keys = vim.api.nvim_replace_termcodes(key.bind .. extra, true, true, true)
		vim.api.nvim_feedkeys(escaped_keys, "m", true)
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
