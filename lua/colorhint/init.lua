local M = {}
local config = require("colorhint.config")
local parser = require("colorhint.parser")
local renderer = require("colorhint.renderer")
local utils = require("colorhint.utils")

-- State
M.ns_id = nil
M.timer = nil
M.enabled = true

-- Setup function
function M.setup(opts)
	config.setup(opts)
	M.ns_id = vim.api.nvim_create_namespace("ColorHint")

	M.setup_autocmds()
	M.setup_commands()
	M.setup_highlights()

	-- Initial highlight
	vim.defer_fn(function()
		if M.is_filetype_enabled() then
			M.highlight_buffer()
		end
	end, 100)
end

-- Setup autocmds
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("ColorHint", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
		group = group,
		callback = function()
			if M.is_filetype_enabled() then
				M.highlight_buffer()
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function()
			if M.is_filetype_enabled() then
				M.schedule_update()
			end
		end,
	})

	-- Clear highlights when leaving buffer
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function()
			if M.timer then
				vim.loop.timer_stop(M.timer)
			end
		end,
	})
end

-- Setup commands
function M.setup_commands()
	vim.api.nvim_create_user_command("ColorHintToggle", function()
		M.toggle()
	end, { desc = "Toggle ColorHint on/off" })

	vim.api.nvim_create_user_command("ColorHintRefresh", function()
		M.highlight_buffer()
	end, { desc = "Refresh color highlighting" })

	vim.api.nvim_create_user_command("ColorHintEnable", function()
		M.enable()
	end, { desc = "Enable ColorHint" })

	vim.api.nvim_create_user_command("ColorHintDisable", function()
		M.disable()
	end, { desc = "Disable ColorHint" })
end

-- Setup default highlights for contrast
function M.setup_highlights()
	-- Fallback highlights for better contrast
	vim.api.nvim_set_hl(0, "ColorHintDarkText", { fg = "#000000" })
	vim.api.nvim_set_hl(0, "ColorHintLightText", { fg = "#ffffff" })
end

-- Check if filetype is enabled
function M.is_filetype_enabled()
	if not M.enabled then
		return false
	end

	local ft = vim.bo.filetype
	local buftype = vim.bo.buftype

	-- Check excluded buftypes
	for _, excluded in ipairs(config.options.exclude_buftypes) do
		if buftype == excluded then
			return false
		end
	end

	-- Check excluded filetypes
	for _, excluded in ipairs(config.options.exclude_filetypes) do
		if ft == excluded then
			return false
		end
	end

	-- Check enabled filetypes
	for _, enabled in ipairs(config.options.filetypes) do
		if enabled == "*" or enabled == ft then
			return true
		end
	end

	return false
end

-- Main highlighting function
function M.highlight_buffer(bufnr)
	if not M.enabled then
		return
	end

	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for line_num, line in ipairs(lines) do
		local colors = parser.parse_line(line)

		for _, color_info in ipairs(colors) do
			renderer.render_color(bufnr, M.ns_id, line_num - 1, color_info)
		end
	end
end

-- Debounced update
function M.schedule_update(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if M.timer then
		vim.loop.timer_stop(M.timer)
	end

	if not M.timer then
		M.timer = vim.loop.new_timer()
	end

	M.timer:start(
		config.options.update_delay,
		0,
		vim.schedule_wrap(function()
			M.highlight_buffer(bufnr)
		end)
	)
end

-- Toggle highlighting
function M.toggle()
	M.enabled = not M.enabled
	if M.enabled then
		M.highlight_buffer()
		utils.notify("ColorHint enabled", "info")
	else
		vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
		utils.notify("ColorHint disabled", "info")
	end
end

-- Enable highlighting
function M.enable()
	M.enabled = true
	M.highlight_buffer()
	utils.notify("ColorHint enabled", "info")
end

-- Disable highlighting
function M.disable()
	M.enabled = false
	vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
	utils.notify("ColorHint disabled", "info")
end

return M
