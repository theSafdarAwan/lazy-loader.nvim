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

	-- add the packer plugin if it exists in the packer_plugins table and is
	-- already not enabled
	if packer_plugins[name] and not packer_plugins[name].enable then
		local del_augroup = plugin.del_autocmd or true
		-- if del_augroup is set to false in the plugin table then don't
		-- delete it maybe its from the mapping loader in which case
		-- there is no augroup
		if del_augroup then
			api.nvim_del_augroup_by_name("lazy_load_" .. name)
		end
		vim.schedule(function()
			packer.loader(name)
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
