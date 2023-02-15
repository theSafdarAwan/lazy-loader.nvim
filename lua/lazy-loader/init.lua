local M = {}

local after = require("lazy-loader.loaders.after").after
local keymap = require("lazy-loader.loaders.keymap").keymap
local autocmd = require("lazy-loader.loaders.autocmd").autocmd
local loader = require("lazy-loader.loaders.loader").loader

local notify = require("lazy-loader.utils").notify

-- TODO: write docs

M.load = function(tbl)
	if not tbl.name then
		local msg = "lazy-loader: Plugin name not provided"
		notify(msg)
		return
	end
	-- general information about the plugin
	local plugin = {
		name = tbl.name,
		cmds = tbl.cmd or tbl.cmds,
		before_load = tbl.before_load,
		on_load = tbl.on_load,
	}

	-- load after a plugin
	if tbl.after then
		local after_tbl = vim.deepcopy(plugin)
		after_tbl.after = tbl.after
		after(after_tbl)
		return
	end

	-- register the autocmd register if provided
	if tbl.autocmd then
		local autocmd_tbl = vim.deepcopy(plugin)
		autocmd_tbl.autocmd = tbl.autocmd
		autocmd(autocmd_tbl)
	end

	-- register keymap register if provided
	if tbl.keymap then
		local keymap_tbl = vim.deepcopy(plugin)
		keymap_tbl.keymap = tbl.keymap
		keymap(keymap_tbl)
	end

	if not tbl.keymap and not tbl.autocmd then
		loader(tbl)
	end
end

return M
