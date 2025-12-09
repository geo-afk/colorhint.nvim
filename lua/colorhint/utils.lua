local M = {}
local config = require("colorhint.config")

-- Notification levels
M.levels = {
	info = vim.log.levels.INFO,
	warn = vim.log.levels.WARN,
	error = vim.log.levels.ERROR,
}

-- Send notification
function M.notify(msg, level)
	if not config.options.enable_notifications then
		return
	end

	level = level or "info"
	local log_level = M.levels[level] or vim.log.levels.INFO

	vim.notify("[ColorHint] " .. msg, log_level)
end

-- Deep merge tables
function M.deep_merge(t1, t2)
	local result = vim.deepcopy(t1)
	for k, v in pairs(t2) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = M.deep_merge(result[k], v)
		else
			result[k] = v
		end
	end
	return result
end

-- Check if value exists in table
function M.has_value(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

-- Debounce function
function M.debounce(fn, delay)
	local timer = nil
	return function(...)
		local args = { ... }
		if timer then
			vim.loop.timer_stop(timer)
		end
		timer = vim.loop.new_timer()
		timer:start(
			delay,
			0,
			vim.schedule_wrap(function()
				fn(unpack(args))
			end)
		)
	end
end

return M
