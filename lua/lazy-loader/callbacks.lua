local vim = vim
local api = vim.api

----------------------------------------------------------------------
--                        Callback functions                        --
----------------------------------------------------------------------

local utils = require("lazy-loader.utils")
local schedule = utils.schedule
local register_autocmd = utils.register_autocmd

local M = {}
----------------------------------------------------------------------
--                            callbacks                             --
----------------------------------------------------------------------

-- callbacks should be defined here because of packer compilation which is why we
-- cant pass references to other functions
local callbacks = {}

-- gitsigns callback function
callbacks.gitsigns = function()
	local gitsigns = "gitsigns.nvim"
	vim.fn.system("git -C " .. vim.fn.expand("%:p:h") .. " rev-parse")
	if vim.v.shell_error == 0 then
		schedule(gitsigns)
	end
end

-- cmp-nvim-lua callback function
callbacks.cmp_nvim_lua = function()
	local plugin = {
		name = "cmp-nvim-lua",
		event = "insertenter",
	}
	local callback = function()
		if vim.bo.filetype ~= "lua" then
			return
		end

		schedule(plugin.name)
	end

	plugin.callback = callback
	register_autocmd(plugin)
end

-- neorg callback function
callbacks.neorg = function()
	local neorg = "neorg"
	schedule(neorg)
	vim.schedule(function()
		require("safdar.plugins.neorg").load_conf()
		-- trick to reload the buffer
		vim.cmd("e")
	end)
end

M.callbacks = callbacks

return M
