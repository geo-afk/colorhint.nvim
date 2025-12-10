local M = {}

-- Lazy-loaded requires (only load when needed)
local function get_config()
	return require("colorhint.config")
end

local function get_parser()
	return require("colorhint.parser")
end

local function get_renderer()
	return require("colorhint.renderer")
end

local function get_utils()
	return require("colorhint.utils")
end

-- State
M.ns_id = nil
M.timer = nil
M.enabled = true

function M.setup(opts)
	-- Now it's safe: this creates the real config module
	require("colorhint.config").setup(opts or {})

	-- Now we can safely require everything else

	M.ns_id = vim.api.nvim_create_namespace("ColorHint")

	M.setup_autocmds()
	M.setup_commands()
	M.setup_highlights()

	-- Initial highlight
	-- vim.defer_fn(function()
	-- 	if M.is_filetype_enabled() and M.is_file_size_ok() then
	-- 		M.highlight_buffer()
	-- 	end
	-- end, 100)
end

-- Setup autocmds
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("ColorHint", { clear = true })

	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = function()
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				M.highlight_buffer()
			end
		end,
	})

	-- Handle filetype changes (Keep this, but remove the defer_fn for simplicity)
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function()
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				-- We can remove the defer_fn here and let it run immediately
				M.highlight_buffer()
			else
				-- Clear if filetype is not supported
				local bufnr = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function()
			if M.is_filetype_enabled() and M.is_file_size_ok() then
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

	-- Handle filetype changes
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function()
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				-- Small delay to let filetype detection settle
				vim.defer_fn(function()
					M.highlight_buffer()
				end, 50)
			else
				-- Clear if filetype is not supported
				local bufnr = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
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

	vim.api.nvim_create_user_command("ColorHintClearCache", function()
		renderer.clear_cache()
		utils.notify("Highlight cache cleared", "info")
	end, { desc = "Clear ColorHint highlight cache" })
end

-- Setup default highlights for contrast
function M.setup_highlights()
	vim.api.nvim_set_hl(0, "ColorHintDarkText", { fg = "#000000" })
	vim.api.nvim_set_hl(0, "ColorHintLightText", { fg = "#ffffff" })
end

-- Check if current file size is acceptable
function M.is_file_size_ok()
	local config = get_config()
	local max_size = config.options.max_file_size
	if not max_size or max_size <= 0 then
		return true
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))

	if ok and stats then
		return stats.size <= max_size
	end

	return true
end

-- Check if filetype is enabled
function M.is_filetype_enabled()
	if not M.enabled then
		return false
	end

	local config = get_config()
	local ft = vim.bo.filetype
	local buftype = vim.bo.buftype

	-- Check excluded buftypes
	if config.options.exclude_buftypes then
		for _, excluded in ipairs(config.options.exclude_buftypes) do
			if buftype == excluded then
				return false
			end
		end
	end

	-- Check excluded filetypes
	if config.options.exclude_filetypes then
		for _, excluded in ipairs(config.options.exclude_filetypes) do
			if ft == excluded then
				return false
			end
		end
	end

	-- Check enabled filetypes
	if config.options.enabled_filetypes then
		for _, enabled in ipairs(config.options.enabled_filetypes) do
			if enabled == "*" or enabled == ft then
				return true
			end
		end
	end

	-- If no enabled_filetypes specified, default to allowing common filetypes
	if not config.options.enabled_filetypes or #config.options.enabled_filetypes == 0 then
		local default_filetypes = {
			"html",
			"css",
			"scss",
			"sass",
			"less",
			"javascript",
			"typescript",
			"javascriptreact",
			"typescriptreact",
			"vue",
			"svelte",
			"astro",
			"lua",
			"python",
		}

		for _, enabled in ipairs(default_filetypes) do
			if ft == enabled then
				return true
			end
		end
	end

	return false
end

-- Main highlighting function with incremental updates
function M.highlight_buffer(bufnr)
	if not M.enabled then
		return
	end

	local parser = get_parser()
	local renderer = get_renderer()
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- Validate buffer
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for line_num, line in ipairs(lines) do
		if line and #line > 0 then
			local colors = parser.parse_line(line)

			for _, color_info in ipairs(colors) do
				renderer.render_color(bufnr, M.ns_id, line_num - 1, color_info)
			end
		end
	end
end

-- Debounced update with mode-aware delay
function M.schedule_update(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if M.timer then
		vim.loop.timer_stop(M.timer)
	end

	if not M.timer then
		M.timer = vim.loop.new_timer()
	end

	-- Longer delay in insert mode for better performance
	local mode = vim.fn.mode()

	local config = get_config()
	local delay = (mode == "i" or mode == "R") and 250 or config.options.update_delay

	M.timer:start(
		delay,
		0,
		vim.schedule_wrap(function()
			if vim.api.nvim_buf_is_valid(bufnr) then
				M.highlight_buffer(bufnr)
			end
		end)
	)
end

-- Toggle highlighting
function M.toggle()
	local utils = get_utils()
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
	local utils = get_utils()
	M.enabled = true
	M.highlight_buffer()
	utils.notify("ColorHint enabled", "info")
end

-- Disable highlighting
function M.disable()
	local utils = get_utils()
	M.enabled = false
	vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
	utils.notify("ColorHint disabled", "info")
end

return M
