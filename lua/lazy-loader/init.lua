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

-- TODO: create docs

local re_write = require("lazy-loader.re-write")
local autocmd_register = re_write.autocmd_register
local keymap_register = re_write.keymap_register

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
		autocmd_register(autocmd_tbl)
	end

	-- register keymap register if provided
	if tbl.keymap then
		local keymap_tbl = vim.deepcopy(plugin)
		keymap_tbl.keymap = tbl.keymap
		keymap_register(keymap_tbl)
	end
end

return M
