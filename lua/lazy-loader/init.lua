-- NOTE: what if the user provides a mapping to load the plugin but doesn't have
-- that mapping specified in his config then we would get an error when trying to
-- delete the autocmd what should we do then.
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
	if packer_plugins[plugin.name] and not packer_plugins[plugin.name].enable then
		-- load the user configuration
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

	-- load the user configuration
	if plugin.on_load and plugin.on_load.config then
		plugin.on_load.config()
	end

	-- execute event if provided in the on_load.event
	if plugin.on_load and plugin.on_load.event then
		vim.schedule(function()
			vim.cmd("silent! do " .. plugin.on_load.event)
		end)
	end

	vim.schedule(function()
		-- a little trick to trigger the reload the buffer after the plugin is loaded
		vim.cmd("silent! do BufEnter")
	end)
end

local api = vim.api
local events = { "BufRead", "BufWinEnter", "BufNewFile" }

local function register_event(autocmd, plugin)
	local pattern = "*"
	if autocmd.ft_ext then
		pattern = "*." .. autocmd.ft_ext
	elseif autocmd.ft then
		pattern = autocmd.ft
	end

	api.nvim_create_autocmd(autocmd.events or autocmd.event or events, {
		group = api.nvim_create_augroup("lazy_load_" .. plugin.name, { clear = true }),
		pattern = pattern,
		callback = function()
			-- validate if the file type matches the autocmd.ft if provided
			if autocmd.ft and vim.bo.filetype ~= autocmd.ft then
				return
			end
			load_plugin(plugin)
		end,
	})
end

-- TODO: add a autocmd for BufEnter so that if the autocmd.ft_ext is provided
-- only add mapping to the buffer files with this pattern
-- to add the mappings

-- to keep track of the plugins mappings added list
local map_plugins_list = {}

local function set_key(key, plugin)
	local function callback(bind)
		load_plugin(plugin)
		if plugin.on_load.cmd then
			vim.schedule(function()
				vim.cmd(plugin.on_load.cmd)
			end)
		end
		-- TODO: read the source code of the packer to understand how
		-- they are handling the keys
		-- TODO:take the input from the user as a mapping
		-- because user might only provide a single mapping
		-- print("bind " .. bind)
		-- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(bind, true, false, true), "n", true)
	end
	vim.keymap.set(key.mode, key.bind, function()
		callback(key.bind)
	end, key.opts or { noremap = true, silent = true })

	-- populate the mapped plugins mappings list
	-- if map_plugins_list[plugin.name] then
	-- 	local idx = plugin.name
	-- 	map_plugins_list[plugin.name][idx + 1] = key
	-- else
	-- 	map_plugins_list[plugin.name] = {}
	-- 	map_plugins_list[plugin.name][1] = key
	-- end
	-- print(vim.inspect(map_plugins_list))
end

-- TODO: if the attach_on_event is true then add an autocmd which with
-- the event name of the plugin then register an event with the same name
-- with this plugin name in callback function of the autocmd for this
-- plugin autocmd register

-- send individual keys to the set_key and plugin table
local function keymap_loader(keys, plugin)
	if keys then
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

-- TODO: add something like keys_on_event so that the mappings should be added

-- @doc expects a table
-- {
--	-- plugin name
-- 	name = "foo", -- string
--	-- boolean value needed when you have to type of registers a keymap and a autocmd
-- 	del_augroup = [[true or false]] , -- boolean
--	-- table of registers for lazy loading currently on 2 are available keymap and autocmd
-- 	registers = {
--		-- this table includes table of keys to add as lazy loader trigger for this plugin
-- 		keymap = {
--			-- adds keymaps only on event register trigger for this mapping
--			attach_on_event = false, -- boolean default false
--			--  table of keys with either a single string or a table
--			-- with mode name and the key
-- 			keys = {
--				"<leader>cc", -- keybind as a string
--				{ "n", "<leader>bc" } -- or a key with the mode and keybind
--			},
--			-- on_load tbl lets you specify config for you plugin
--			-- like requiring the config file for the plugin this
--			-- will be required after the plugin is loaded.
--			on_load = {
--				-- this will be executed to open the plugin if need need that.
-- 				cmd = "echo 'Hello, World!'",
-- 				-- this key is just like packer config key require
-- 				-- your config files in here
-- 				config = function()
-- 					require("foo.bar")
-- 					-- or
-- 					require("bar.baz").setup({ --[[config goes here]]})
-- 				end,
-- 			},
-- 		},
-- 		-- this register adds an autocmd for the specified plugin
-- 		autocmd = {
--			-- TODO: add the events documentation
--			--
--			-- event or events are the same use whatever you want
--			event = "name of the events", -- string
--			events = "name of the events", -- string
--			-- this key acts as a buffer file validator to which the
--			-- autocmd should be attached you need to specify the filetype
--			-- or file extension of the file that you want plugin to be
--			-- loaded on the events that you provided.
-- 			ft = "markdown", -- markdown file type
-- 			ft = "md", -- markdown file type
-- 			-- NOTE:ft_ext is very helpful for filetypes like neorg which
-- 			-- are set after the treesitter you won't be able to lazy
-- 			-- lazy_load the neorg if you are also lazy loading treesitter
--			--
-- 			-- ft_ext = "norg", -- or filetype extension
--			on_load = { -- see keymap.on_load },
-- 		},
-- 	},
-- }

M.loader = function(tbl)
	local autocmd = tbl.registers.autocmd
	local keymap = tbl.registers.keymap

	local after = keymap and keymap.after or autocmd and autocmd.after

	-- plugin tbl needed for all registers to load plugin
	local plugin = {
		name = tbl.name,
		del_augroup = tbl.del_augroup,
		packadd = tbl.packadd,
		on_load = tbl.on_load,
		before_load = tbl.before_load,
	}
	-- if both autocmd and mapping registers are added then add maps callback
	-- function to delete the augroup after the plugin is loaded through a map
	-- NOTE: what if user provides the callback and the on_load.confg maybe give warning
	if keymap and autocmd then
		-- if after and after == "keymap" then
		-- 	keymap_loader(keymap.keys, plugin)
		-- elseif after and after == "autocmd" then
		-- 	register_event(autocmd, plugin)
		-- else
		keymap_loader(keymap.keys, plugin)
		register_event(autocmd, plugin)
		-- end
	elseif keymap and keymap.keys then
		-- if only the keymap register is added
		keymap_loader(keymap.keys, plugin)
	elseif autocmd then
		-- if only autocmd register is added
		register_event(autocmd, plugin)
	end
end

return M
