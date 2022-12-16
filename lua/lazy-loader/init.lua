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
	local buf_reload = false
	-- you can also add a plugin using packadd also
	if plugin.packadd then
		vim.cmd("silent! packadd " .. plugin.name)
		buf_reload = true
	end

	if packer_plugins[plugin.name] and not packer_plugins[plugin.name].enable then
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end
		packer.loader(plugin.name)
		buf_reload = true
	elseif packer_plugins[plugin.name] and packer_plugins[plugin.name].enable then
		if plugin.del_augroup then
			vim.api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
		end
	end

	-- load the user configuration
	if plugin.on_load.config then
		plugin.on_load.config()
		buf_reload = true
	end

	-- execute event if provided in the on_load.event
	if plugin.on_load.event then
		vim.schedule(function()
			vim.cmd("silent! do " .. plugin.on_load.event)
		end)
	end

	if buf_reload then
		-- a little trick to trigger the reload the buffer after the plugin is loaded
		vim.schedule(function()
			vim.cmd("silent! do BufEnter")
		end)
	end
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
			-- call the callback function which is either provided by
			-- the user in the aucomand register or
			-- if not provieded there then will be overridden with the
			-- on_load.config
			autocmd.callback()
		end,
	})
end

-- TODO: add a autocmd for BufEnter so that if the autocmd.ft_ext is provided
-- only add mapping to the buffer files with this pattern
-- to add the mappings

-- TODO: add feedkey function to which we give a table of mappings with the
-- information attached to it like plugin name and then after the plugin is
-- loaded we remove all the mappings in that table
local function set_key(key, plugin)
	local function callback()
		load_plugin(plugin)
		if plugin.on_load.cmd then
			vim.schedule(function()
				vim.cmd(plugin.on_load.cmd)
			end)
		end
	end
	vim.keymap.set(key.mode, key.bind, function()
		callback()
	end, key.opts or { noremap = true, silent = true })
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
			set_key({ mode = mode, bind = bind, opts = { noremap = true, silent = true } }, plugin)
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
-- 	-- boolean value add plugin as a package for plugin that need to be added that don't
-- 	-- have a setup function like undotree
-- 	packadd = [[true or false]], -- boolean
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
--				-- events on which this plugin should be loaded if no events are provided
--				-- then defaults are =>  "BufRead", "BufWinEnter", "BufNewFile"
--				[[event or events]] = {"BufRead", "Insertenter"},
--				-- which will be executed to open the plugin if need need that.
-- 				cmd = "echo 'Hello, World!'",
-- 				-- this key is just like packer config key
-- 				config = function()
-- 					require("foo.bar")
-- 					-- or
-- 					require("bar.baz").setup({ --[[config goes here]]})
-- 				end,
-- 				-- event Like BufRead or BufEnter to reload the
-- 				-- buffer after the plugin is loaded
-- 				event = "BufEnter"
-- 			},
-- 		},
-- 		-- this register adds an autocmd for the specified plugin
-- 		autocmd = {
--			-- this key acts as a buffer file validator to which the
--			-- autocmd should be attached you need to specify the filetype
--			-- or file extension of the file that you want plugin to be
--			-- loaded on the events that you provided.
-- 			ft = "markdown", -- markdown file type
-- 			ft = "md", -- markdown file type
-- 			-- NOTE:ft_ext is very helpful for filetypes like neorg which
-- 			-- are set after the treesitter you won't be able to lazy
-- 			-- lazy_load the neorg if you are also lazy loading treesitter
-- 			-- ft_ext = "norg", -- or filetype extension
-- 		},
-- 	},
-- }

-- TODO: Provide the same config as the keymap to the autocmd register and add
-- the after key which defines which register has to complete first
-- Like in my case i want to add markdown-preview plugin mappings only after the
-- markdown file is opened: autocmd first and after that keymap
M.loader = function(tbl)
	local autocmd = tbl.registers.autocmd
	local keymap = tbl.registers.keymap

	-- plugin tbl needed for all registers to load plugin
	local plugin = {
		name = tbl.name,
		del_augroup = tbl.del_augroup,
		callback = tbl.registers.keymap.on_load.config,
		packadd = tbl.packadd,
		on_load = tbl.registers.keymap.on_load,
	}
	-- if both autocmd and mapping registers are added then add maps callback
	-- function to delete the augroup after the plugin is loaded through a map
	-- NOTE: what if user provides the callback and the on_load.confg maybe give warning
	if keymap and autocmd then
		-- check if the autocmd doesn't have callback function already defined
		if not autocmd.callback then
			autocmd.callback = function()
				load_plugin(plugin)
				plugin.on_load.config()
			end
		end
		keymap_loader(keymap.keys, plugin)
		register_event(autocmd, plugin)
	end

	-- if only the keymap register is added
	if keymap.keys then
		keymap_loader(keymap.keys, plugin)
	end
end

return M
