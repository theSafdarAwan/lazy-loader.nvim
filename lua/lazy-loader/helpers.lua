local M = {}

local vim = vim
local api = vim.api
local packer = require("packer")
local packer_plugins = _G.packer_plugins

-- add the plugin package expects name of the plugin
function M.add_package(name)
	vim.cmd("silent! packadd " .. name)
end

local events = { "BufRead", "BufWinEnter", "BufNewFile" }

-- schedule the loading of the plugin and deletes the autocmd group expects name
-- of the plugin or a tbl with name key and del_autocmd key with boolean value
function M.schedule(plugin)
	local name
	if type(plugin) == "string" then
		name = plugin
	else
		name = plugin.name
	end

	-- add plugin package if packadd key is provided with the boolean true
	if plugin.packadd then
		vim.schedule(function()
			M.add_package(plugin.name)
		end)
		return
	end

	-- add the plugin from packer loader if it exists in the packer_plugins table and
	-- already not enabled
	if packer_plugins[name] and not packer_plugins[name].enable then
		local del_augroup = plugin.del_autocmd or true

		-- TODO: extract the del_augroup into its own function and use it
		-- from there maybe use it in multiple places
		--
		-- if del_augroup is set to false in the plugin table then don't
		-- delete it maybe its from the mapping loader in which case
		-- there is no augroup
		if del_augroup then
			api.nvim_del_augroup_by_name("lazy_load_" .. name)
		end
		vim.schedule(function()
			packer.loader(name)

			-- if the plugin is going to be used for a specifice
			-- filetype to reload the buffer after loading the
			-- plugin
			if plugin.ft then
				vim.cmd("silent! do BufEnter")
			end

			-- TODO: move this to the on_plugin loader function and
			-- add a simple schedule loader function rather then this
			-- Keep in mind this will be used fro the norg ftype also
			if name == "nvim-lspconfig" then
				vim.cmd("silent! do FileType")
			end
		end)
	elseif packer_plugins[name] and packer_plugins[name].enabled then
		-- delete the augroup group if the plugin is already loaded
		api.nvim_del_augroup_by_name("lazy_load_" .. name)
	end
end

-- this function needs a tbl with this info
-- {
--	name = "plugin name to set the augroup name", -- string
--	events = "name of the evens either one or a tbl of events", -- tbl|string
--	pattern = "see :autocmd-pattern", -- string
--	callback = "function to do something either condition checking or something", -- function
-- }
function M.register_autocmd(plugin)
	api.nvim_create_autocmd(plugin.events or plugin.event or events, {
		group = api.nvim_create_augroup("lazy_load_" .. tostring(plugin.name), { clear = true }),
		pattern = plugin.pattern,
		command = plugin.cmd,
		callback = plugin.callback,
	})
end

return M