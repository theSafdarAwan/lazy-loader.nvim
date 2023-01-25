local M = {}

local fn = vim.fn
local api = vim.api

local notify = require("lazy-loader.utils").notify
local loader = require("lazy-loader.loaders.loader").loader

local event_generator = require("lazy-loader.utils").event_generator

function M.after(after_tbl)
	local packer_path = fn.stdpath("data") .. "/site/pack/packer"
	if type(after_tbl.after) ~= "string" then
		notify({ msg = "after plugin is not a string for: ", level = vim.log.levels.ERROR })
		return
	elseif
		fn.empty(vim.fn.glob(packer_path .. "/start/" .. after_tbl.after)) < 0
		or fn.empty(vim.fn.glob(packer_path .. "/opt/" .. after_tbl.after)) < 0
	then
		notify(
			"lazy-loader: "
				.. after_tbl.after
				.. " not found cant load "
				.. after_tbl.name
				.. "first install the plugin"
		)
		return
	end

	local augroup_name = "lazy loading " .. after_tbl.name .. " after " .. after_tbl.after
	event_generator({
		event = "User",
		group_name = augroup_name,
		pattern = after_tbl.after .. " has been loaded",
		callback = function()
			loader(after_tbl)
			api.nvim_del_augroup_by_name(augroup_name)
		end,
	})
end

return M
