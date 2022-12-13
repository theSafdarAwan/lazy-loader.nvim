local M = {}

local vim = vim
----------------------------------------------------------------------
--                        lazy loader utils                         --
----------------------------------------------------------------------
local packer = require("packer")
local packer_plugins = _G.packer_plugins

local utils = require("lazy-loader.helpers")
local schedule = utils.schedule
local register_autocmd = utils.register_autocmd
local add_package = utils.add_package
local callbacks = require("lazy-loader.callbacks").callbacks

----------------------------------------------------------------------
--                         Plugins Loaders                          --
----------------------------------------------------------------------
local loaders = {}

----------------------------------------------------------------------
--                          Callback Loder                          --
----------------------------------------------------------------------

-- plugins that have callback function defined in the callbacks table
local plugins_callbacks = {
	["neorg"] = callbacks.neorg,
	["gitsigns.nvim"] = callbacks.gitsigns,
	["cmp-nvim-lua"] = callbacks.cmp_nvim_lua,
}

-- depends on what you did in the callback function
-- for plugins that need a callback which is defined in the callbacks tbl
loaders.callback = function(plugin)
	for k, v in pairs(plugins_callbacks) do
		if plugin.name == k then
			plugin.callback = v
			register_autocmd(plugin)
			return
		end
	end
end

----------------------------------------------------------------------
--                          Keymap Loader                           --
----------------------------------------------------------------------

-- to add the mappings
local function set_keymap(key, plugin, callback)
	-- if user only gave string key binding rather then table for mapping
	local mode = "n"
	local binding = key
	if type(key) == "table" then
		mode = key[1]
		binding = key[2]
	end

	vim.keymap.set(mode, binding, function()
		callback(plugin, key)
	end, key[3] or { noremap = true, silent = true })
end

-- to load the keymap plugin
local keymap_callback = function(plugin, key)
	if packer_plugins[plugin.name] and not packer_plugins[plugin.name].enable then
		-- add plugin as a package or load using packer loader
		if plugin.packadd then
			add_package(plugin.name)
		else
			packer.loader(plugin.name)
		end

		-- in callback you should provide the require modules
		if plugin.callback then
			plugin.callback()
		end

		-- if plugin already has an autocmd to be loaded
		if plugin.del_autocmd then
			schedule({ name = plugin.name, del_autocmd = plugin.del_autocmd })
		end

		-- TODO: add something lie on_loading or something where
		-- execute_cmd should be defined to reduce the ambiguity between
		-- which key is for loading and which is after loading the plugin

		-- to execute command as soon as the plugin is loaded
		if plugin.execute_cmd then
			vim.schedule(function()
				vim.cmd(plugin.execute_cmd)
			end)
		end

		-- TODO: work on this and after this lazy_load the harpoon using this
		-- if key.feedkey then
		-- 	vim.schedule(function()
		-- 		vim.fn.feedkeys(key[2], key[1])
		-- 	end)
		-- end
	end
end

-- NOTE: the mappings that you are giving here should be defined before you load
-- the plugin mappings maybe load the plugin mappings in the callback function
-- but not before these. And also to overridden these mappings when you require
-- you plugin mappings.

-- To lazy load plugins with mappings
-- expects two tables
-- 1) plugin information
-- {
--	name = "plugin name" -- string
--	callback = function() --[[ to load plugin configuration and maps ]] end, -- function
--	del_autocmd = "boolean value to delete the autocmd if exists or not useful for plugins that have keymaps and also autocmds to load", -- boolean
--	packadd = "add plugin as a package", -- boolean
--	execute_cmd = "command to execute after the plugin is loaded helpful when you want to open the plugin as soon as you loaded", -- string
--  }
-- 2) keymaps you can add as many keymaps as you want there is no need to add key
--    for the mapping just add the kymap tbl
-- {
--	{
--		"mode",--  string
--		"key", -- string
--		{ "tbl of opts this is optional" }, -- tbl
--	}
-- }
loaders.keymap = function(plugin, keys)
	for _, key in pairs(keys) do
		set_keymap(key, plugin, keymap_callback)
	end
end

----------------------------------------------------------------------
--                          On File Loader                          --
----------------------------------------------------------------------

-- plugins that need to be loaded before files like treesitter
loaders.on_file = function(plugin)
	plugin.callback = function()
		packer.loader(plugin.name)
	end
	register_autocmd(plugin)
end

----------------------------------------------------------------------
--                      Schedul Autocmd Loader                      --
----------------------------------------------------------------------

-- schedule plugin loading with the event
loaders.schedule_autocmd = function(plugin)
	plugin.callback = function()
		schedule({ name = plugin.name, ft = plugin.ft or false })
	end
	register_autocmd(plugin)
end

M.loaders = loaders

----------------------------------------------------------------------
--                             Re-write                             --
----------------------------------------------------------------------
local function load_plugin(plugin)
	if plugin.packadd then
		vim.cmd("silent! packadd " .. plugin.name)
	end
	if packer_plugins[plugin.name] and not packer_plugins[plugin.name].enable then
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end
		packer.loader(plugin.name)
	elseif packer_plugins[plugin.name] and packer_plugins[plugin.name].enable then
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end
	end
	-- load the user configuration
	if plugin.on_load.config then
		plugin.on_load.config()
	end
end

local api = vim.api
local events = { "BufRead", "BufWinEnter", "BufNewFile" }

local function register_event(autocmd, plugin)
	local pattern = nil
	if autocmd.ft_ext then
		pattern = "*." .. autocmd.ft_ext
	end
	api.nvim_create_autocmd(autocmd.events or autocmd.event or events, {
		group = api.nvim_create_augroup("lazy_load_" .. tostring(plugin.name), { clear = true }),
		pattern = pattern,
		callback = function()
			autocmd.callback()
			if plugin.on_load.cmd then
				schedule(function()
					vim.cmd(plugin.on_load.cmd)
				end)
			end
		end,
	})
end

-- to add the mappings
local function set_key(key, plugin)
	local function callback()
		if plugin.del_augroup then
			load_plugin(plugin)
			vim.cmd(plugin.on_load.cmd)
		else
			packer.loader(plugin.name)
			vim.schedule(function()
				vim.cmd(plugin.on_load.cmd)
			end)
		end
	end
	vim.keymap.set(key.mode, key.bind, function()
		callback()
	end, key.opts or { noremap = true, silent = true })
end

-- send individual keys to the set_key
local function keymap_loader(keys, plugin)
	if keys then
		for _, k in pairs(keys) do
			local mode = "n"
			local bind = k
			if type(k) == "table" then
				mode = k[1]
				bind = k[2]
			end
			set_key({ mode = mode, bind = bind, opts = { noremap = true, silent = true } }, plugin)
		end
	end
end

-- @doc expects a table
-- {
--	-- plugin name
-- 	name = "foo", -- string
--	-- boolean value needed when you have to type of registers a keymap and a autocmd
-- 	del_augroup = [[true|false]] , -- boolean
-- 	-- boolean value add plugin as a package for plugin that need to be added that don't
-- 	-- have a setup function like undotree
-- 	packadd = [[true|false]] -- boolean
--	-- table of registers for lazy loading currently on 2 are available keymap and autocmd
-- 	registers = {
--		-- this table includes table of keys to add as lazy loader trigger for this plugin
-- 		keymap = {
--			--  table of keys with either a single string or a table
--			-- with mode name and the key
-- 			keys = {
--				"<leader>cc", -- keybind as a string
--				{ "n", "<leader>bc" } -- or a key with the mode and keybind
--			},
--			-- on_load tbl lets you specify config for you plugin
--			-- like requiring the config file for the plugin this
--			-- will be required after the plugin is loaded and a cmd
--			-- which will be executed to open the plugin if need need
--			-- that.
-- 			on_load = {
-- 				cmd = "echo 'Hello, World!'",
-- 				-- this key is just like packer config key
-- 				config = function()
-- 					require("foo.bar")
-- 					-- or
-- 					require("bar.baz").setup({ -- config goes here})
-- 				end,
-- 			},
-- 		},
-- 		-- this register adds an autocmd for the specified plugin
-- 		autocmd = {
--			-- this key acts as a buffer file validator you need to
--			-- specify the file extension of the file that you want
--			-- plugin to be loaded on the events that you provided.
-- 			ft_ext = "norg",
-- 		},
-- 	},
-- }
M.loader = function(tbl)
	local autocmd = tbl.registers.autocmd
	local keys = tbl.registers.keymap.keys

	-- plugin tbl needed for all registers to load plugin
	local plugin = {
		name = tbl.name,
		del_augroup = tbl.del_augroup,
		callback = tbl.registers.keymap.on_load.config,
		packadd = tbl.packadd,
		on_load = tbl.registers.keymap.on_load,
	}
	-- if both autocmd and mapping registers are added then add maps callback
	-- function with to delete the augroup after the plugin is loaded through
	-- a map
	if keys and autocmd then
		if not autocmd.callback then
			autocmd.callback = function()
				load_plugin(plugin)
				plugin.on_load.config()
			end
		end
		keymap_loader(keys, plugin)
		register_event(autocmd, plugin)
	end
end

return M
