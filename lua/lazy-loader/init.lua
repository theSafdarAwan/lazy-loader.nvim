local vim = vim
local M = {}

----------------------------------------------------------------------
--                        lazy loader utils                         --
----------------------------------------------------------------------
local packer = require("packer")
local packer_plugins = _G.packer_plugins

local del_augroup = function(name)
	vim.api.nvim_del_augroup_by_name("lazy_load_" .. name)
end

----------------------------------------------------------------------
--                          Plugin Loader                           --
----------------------------------------------------------------------
function M.load_plugin(plugin)
	if packer_plugins[plugin.name] and not packer_plugins[plugin.name].enable then
		-- load the user configuration before loading plugin
		if plugin.before_load and plugin.before_load.config then
			plugin.before_load.config()
		end

		-- load plugins if the plugin requires
		if plugin.requires then
			local plugins = plugin.requires

			if type(plugins) == "table" then
				for _, p in pairs(plugins) do
					M.load_plugin(p)
				end
			elseif type(plugins) == "string" then
				M.load_plugin(plugins)
			end
		end

		if plugin.del_augroup then
			del_augroup(plugin.name)
		end

		-- add the package this is important else you won't be able to
		-- execute the command from command line for this plugin's you lazy loaded
		vim.cmd("silent! packadd " .. plugin.name)
		packer.loader(plugin.name)
	elseif packer_plugins[plugin.name] and packer_plugins[plugin.name].enable then
		if plugin.del_augroup then
			del_augroup(plugin.name)
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
		vim.cmd("silent! do " .. plugin.on_load.event)
	else
		-- a little trick to trigger the reload the buffer after the plugin is loaded
		vim.cmd("silent! do BufEnter")
	end

	if plugin.on_load and plugin.on_load.cmd then
		vim.cmd(plugin.on_load.cmd)
	end
end

local api = vim.api
local default_events = { "BufRead", "BufWinEnter", "BufNewFile" }

----------------------------------------------------------------------
--                         Autocmd Register                         --
----------------------------------------------------------------------
local function register_event(name, events, pattern, callback)
	api.nvim_create_autocmd(events or default_events, {
		group = api.nvim_create_augroup("lazy_load_" .. name, { clear = true }),
		pattern = pattern,
		callback = callback,
	})
end
function M.autocmd_register(plugin)
	local autocmd = plugin.autocmd
	local events = autocmd.event or autocmd.events
	-- filetype extesion pattern for the autocmd
	local pattern
	-- to use file as a pattern
	local ft_ext = autocmd.ft_ext
	if ft_ext and type(ft_ext) == "string" then
		pattern = "*." .. ft_ext
	elseif ft_ext and type(ft_ext) == "table" then
		pattern = {}
		for _, ext in pairs(ft_ext) do
			pattern[#pattern + 1] = "*." .. ext
		end
	end

	local callback_loader = function()
		if autocmd.callback and not autocmd.callback() then
			return
		else
			if autocmd and autocmd.keymap then
				-- convert the autocmd plugin tbl to keymap_tbl
				local keymap_tbl = vim.deepcopy(plugin)
				keymap_tbl.keymap = autocmd.keymap
				-- need to delete the augroup for this plugin
				keymap_tbl.del_augroup = true
				keymap_tbl.autocmd = nil
				M.keymap_register(keymap_tbl)
			else
				M.load_plugin(plugin)
			end
		end
	end

	if autocmd.ft then
		-- if filetyp is provided then add FileType event
		register_event(plugin.name, "FileType", autocmd.ft, function()
			register_event(plugin.name, events, pattern, function()
				if vim.bo.filetype ~= autocmd.ft then
					return
				else
					callback_loader()
				end
			end)
		end)
	else
		register_event(plugin.name, events, pattern, callback_loader)
	end
end

----------------------------------------------------------------------
--                          Keymap Loader                           --
----------------------------------------------------------------------
local function set_key(key, plugin)
	vim.keymap.set(key.mode, key.bind, function()
		-- NOTE:Important: need to delete this map before the plugin loading because now the mappings
		-- for plugin will be loaded
		vim.keymap.del(key.mode, key.bind)

		M.load_plugin(plugin)

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
		-- vim.cmd("silent! do BufRead")
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

----------------------------------------------------------------------
--                        Without Any Delay                         --
----------------------------------------------------------------------
function M.no_delay(plugin_tbl)
	M.load_plugin(plugin_tbl)
end

----------------------------------------------------------------------
--                             Re-write                             --
----------------------------------------------------------------------

-- TODO: create docs

M.loader = function(tbl)
	-- TODO: remove the augroup and dynamically add and remove the del_augroup

	-- general information about the plugin
	local plugin = {
		name = tbl.name,
		before_load = tbl.before_load,
		on_load = tbl.on_load,
	}

	-- register the autocmd register if provided
	if tbl.autocmd then
		local autocmd_tbl = vim.deepcopy(plugin)
		autocmd_tbl.autocmd = tbl.autocmd
		M.autocmd_register(autocmd_tbl)
	end

	-- register keymap register if provided
	if tbl.keymap then
		local keymap_tbl = vim.deepcopy(plugin)
		keymap_tbl.keymap = tbl.keymap
		M.keymap_register(keymap_tbl)
	end

	if not tbl.keymap and not tbl.autocmd then
		M.no_delay(tbl)
	end
end

return M
