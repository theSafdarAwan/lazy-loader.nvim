local M = {}

local event_generator = require("lazy-loader.utils").event_generator
local loader = require("lazy-loader.loaders.loader").loader

function M.autocmd(plugin)
	local autocmd = plugin.autocmd
	local events = autocmd.event or autocmd.events
	-- filetype extension pattern for the autocmd
	local pattern
	-- to use file as a pattern
	local ft_extension = autocmd.ft_ext
	if ft_extension and type(ft_extension) == "string" then
		pattern = "*." .. ft_extension
	elseif ft_extension and type(ft_extension) == "table" then
		pattern = {}
		for _, ext in pairs(ft_extension) do
			pattern[#pattern + 1] = "*." .. ext
		end
	end

	local callback_loader = function()
		if autocmd.callback and not autocmd.callback() then
			return
		else
			if autocmd and autocmd.keymap then
				-- convert the autocmd plugin tbl to keymap_tbl
				local keymap_tbl = vim.deepcopy(plugin)
				keymap_tbl.keymap = autocmd.keymap
				keymap_tbl.autocmd = nil
				M.keymap_register(keymap_tbl)
			else
				loader(plugin)
			end
		end
	end

	local augroup_name = "lazy_load_" .. plugin.name
	if autocmd.ft then
		-- if filetyp is provided then add FileType event
		event_generator({
			group_name = augroup_name,
			event = "FileType",
			pattern = autocmd.ft,
			callback = function()
				event_generator({
					group_name = augroup_name,
					events = events,
					pattern = pattern,
					callback = function()
						if vim.bo.filetype ~= autocmd.ft then
							return
						else
							callback_loader()
						end
					end,
				})
			end,
		})
	else
		event_generator({
			group_name = augroup_name,
			events = events,
			pattern = pattern,
			callback = callback_loader,
		})
	end
end

return M
