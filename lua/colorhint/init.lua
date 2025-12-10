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
M.positions_cache = {} -- New: Cache positions to avoid redundant highlights (borrowed)

function M.setup(opts)
	-- Now it's safe: this creates the real config module
	require("colorhint.config").setup(opts or {})

	-- Now we can safely require everything else

	M.ns_id = vim.api.nvim_create_namespace("ColorHint")

	M.setup_autocmds()
	M.setup_commands()
	M.setup_highlights()

	-- Initial highlight
	vim.defer_fn(function()
		if M.is_filetype_enabled() and M.is_file_size_ok() then
			M.highlight_buffer()
		end
	end, 100)
end

-- Setup autocmds (updated with borrowed events)
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

	-- Handle filetype changes
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function()
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				M.highlight_buffer()
			else
				-- Clear if filetype is not supported
				local bufnr = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
			end
		end,
	})

	-- Borrowed: More responsive updates
	vim.api.nvim_create_autocmd({
		"TextChanged",
		"InsertLeave",
		"TextChangedP",
		"LspAttach",
		"BufEnter",
	}, {
		group = group,
		callback = function(ev)
			if ev.event == "LspAttach" and get_config().options.enable_lsp then
				M.highlight_with_lsp(ev.buf, M.ns_id)
			end
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				M.schedule_update()
			end
		end,
	})

	-- Borrowed: Handle window changes
	vim.api.nvim_create_autocmd({
		"VimResized",
		"WinScrolled",
	}, {
		group = group,
		callback = function()
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				M.highlight_buffer()
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

-- Setup commands (borrowed structure)
function M.setup_commands()
	vim.api.nvim_create_user_command("ColorHint", function(opts)
		local arg = string.lower(opts.fargs[1])
		if arg == "on" then
			M.enable()
		elseif arg == "off" then
			M.disable()
		elseif arg == "toggle" then
			M.toggle()
		elseif arg == "isactive" then
			M.is_active()
		elseif arg == "refresh" then
			M.highlight_buffer()
		end
	end, {
		nargs = 1,
		complete = function()
			return { "On", "Off", "Toggle", "IsActive", "Refresh" }
		end,
		desc = "Control ColorHint",
	})
end

-- Setup default highlights for contrast (updated with borrowed fg)
function M.setup_highlights()
	vim.api.nvim_set_hl(0, "ColorHintDarkText", { fg = "#000000" })
	vim.api.nvim_set_hl(0, "ColorHintLightText", { fg = "#ffffff" })
end

-- Check if current file size is acceptable (unchanged)
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

-- Check if filetype is enabled (unchanged)
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

-- New: Borrowed LSP integration
function M.highlight_with_lsp(active_buffer_id, ns_id)
	local param = { textDocument = vim.lsp.util.make_text_document_params(active_buffer_id) }
	local clients = M.get_lsp_clients(active_buffer_id)

	for _, client in pairs(clients) do
		if client.supports_method("textDocument/documentColor", { bufnr = active_buffer_id }) then
			client.request("textDocument/documentColor", param, function(_, response)
				M.highlight_lsp_document_color(
					response,
					active_buffer_id,
					ns_id,
					M.positions_cache[active_buffer_id] or {},
					get_config().options
				)
			end, active_buffer_id)
		end
	end
end

-- Borrowed: Highlight LSP colors
function M.highlight_lsp_document_color(response, active_buffer_id, ns_id, positions, options)
	local results = {}
	if response == nil then
		return
	end

	for _, match in pairs(response) do
		local r, g, b, a = match.color.red or 0, match.color.green or 0, match.color.blue or 0, match.color.alpha or 0
		local value = string.format("#%02x%02x%02x", r * a * 255, g * a * 255, b * a * 255)
		local range = match.range
		local start_column = range.start.character
		local end_column = range["end"].character
		local row = range.start.line

		local is_already_highlighted = false
		for _, pos in ipairs(positions) do
			if
				pos.row == row
				and pos.start_column == start_column
				and pos.end_column == end_column
				and pos.value == value
			then
				is_already_highlighted = true
				break
			end
		end

		local result = {
			row = row,
			start_column = start_column,
			end_column = end_column,
			value = value,
		}

		if not is_already_highlighted then
			get_renderer().render_color(
				active_buffer_id,
				ns_id,
				row,
				{ start = start_column, finish = end_column, color = value, format = "lsp" }
			)
		end
		table.insert(results, result)
	end

	M.positions_cache[active_buffer_id] = results
	return results
end

-- Borrowed: Get LSP clients
function M.get_lsp_clients(active_buffer_id, client_name)
	local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
	return get_clients({ bufnr = active_buffer_id, name = client_name })
end

-- Main highlighting function with incremental updates (updated with positions cache)
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
	M.positions_cache[bufnr] = {}

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for line_num, line in ipairs(lines) do
		if line and #line > 0 then
			local colors = parser.parse_line(line)

			for _, color_info in ipairs(colors) do
				renderer.render_color(bufnr, M.ns_id, line_num - 1, color_info)
				table.insert(
					M.positions_cache[bufnr],
					{
						row = line_num - 1,
						start_column = color_info.start,
						end_column = color_info.finish,
						value = color_info.color,
					}
				)
			end
		end
	end

	if get_config().options.enable_lsp then
		M.highlight_with_lsp(bufnr, M.ns_id)
	end
end

-- Debounced update with mode-aware delay (unchanged)
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

-- Toggle highlighting (unchanged)
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

-- Enable highlighting (unchanged)
function M.enable()
	local utils = get_utils()
	M.enabled = true
	M.highlight_buffer()
	utils.notify("ColorHint enabled", "info")
end

-- Disable highlighting (unchanged)
function M.disable()
	local utils = get_utils()
	M.enabled = false
	vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
	utils.notify("ColorHint disabled", "info")
end

-- New: Borrowed is_active
function M.is_active()
	local utils = get_utils()
	utils.notify(M.enabled and "ColorHint is active" or "ColorHint is inactive", "info")
end

return M
