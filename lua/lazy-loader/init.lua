local vim = vim
local M = {}
----------------------------------------------------------------------
--                             Re-write                             --
----------------------------------------------------------------------

-- TODO: create docs

local re_write = require("lazy-loader.re-write")
local autocmd_register = re_write.autocmd_register
local keymap_register = re_write.keymap_register
local no_delay = re_write.no_delay

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

	if not tbl.keymap and not tbl.autocmd then
		no_delay(tbl)
	end
end

return M
