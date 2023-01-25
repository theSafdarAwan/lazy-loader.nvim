local M = {}

local packer = require("packer")
local packer_plugins = _G.packer_plugins

local api = vim.api
local command = vim.api.nvim_command

----------------------------------------------------------------------
--                          Plugin Loader                           --
----------------------------------------------------------------------
function M.plugin_loader(plugin)
	local ok, _ = pcall(vim.api.nvim_get_autocmds, { group = "lazy_load_" .. plugin.name })
	if ok then
		api.nvim_del_augroup_by_name("lazy_load_" .. plugin.name)
	end

	if packer_plugins[plugin.name] and packer_plugins[plugin.name].enable then
		require("lazy-loader.utils").notify("lazy-loader: " .. plugin.name .. " is already loaded")
		return
	end

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

	-- add the package this is important else you won't be able to
	-- execute the command from command line for this plugin's you lazy loaded
	command("silent! packadd " .. plugin.name)
	packer.loader(plugin.name)

	if plugin.on_load then
		-- load the user configuration after loading plugin
		if plugin.on_load.config then
			plugin.on_load.config()
		end

		if plugin.on_load.cmd then
			command(plugin.on_load.cmd)
		end

		if plugin.on_load.reload_buffer then
			command("silent! do BufEnter")
		end
	end

	if plugin.cmds then
		for _, cmd in pairs(plugin.cmds) do
			api.nvim_create_user_command(cmd, function()
				command(cmd)
			end, {})
		end
	end

	pcall(command, "silent! do User " .. plugin.name .. " has been loaded")
end

return M
