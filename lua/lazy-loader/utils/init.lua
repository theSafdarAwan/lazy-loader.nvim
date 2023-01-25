local M = {}
local api = vim.api
M.notify = function(notify)
	local level = vim.log.levels.WARN or notify.level

	if not notify then
		api.nvim_notify("lazy-loader: notify table is not valid", level, notify.opts or {})
		return
	end

	local msg
	if type(notify) == "string" then
		msg = notify
	elseif notify.msg and type(notify.msg) == "string" then
		msg = notify.msg
	elseif type(notify.msg) == "nil" then
		api.nvim_notify("lazy-loader: notify message is not valid", level, notify.opts or {})
		return
	end
	api.nvim_notify(msg, level, notify.opts or {})
end

local default_events = { "BufRead", "BufWinEnter", "BufNewFile" }
function M.event_generator(tbl)
	local events = tbl.events or tbl.event or default_events
	api.nvim_create_autocmd(events, {
		group = api.nvim_create_augroup(tbl.group_name, { clear = true }),
		pattern = tbl.pattern,
		callback = tbl.callback,
	})
end

return M
