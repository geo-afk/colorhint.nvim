local M = {}

-- Lazy-loaded modules
local config, parser, renderer, utils

local function get_config()
	if not config then
		config = require("colorhint.config")
	end
	return config
end

local function get_parser()
	if not parser then
		parser = require("colorhint.parser")
	end
	return parser
end

local function get_renderer()
	if not renderer then
		renderer = require("colorhint.renderer")
	end
	return renderer
end

local function get_utils()
	if not utils then
		utils = require("colorhint.utils")
	end
	return utils
end

-- State
M.ns_id = nil
M.timer = nil
M.enabled = true
M.positions_cache = {}
M.last_update = {} -- Track last update time per buffer

-- IMPROVED: Setup with validation
function M.setup(opts)
	get_config().setup(opts or {})
	M.ns_id = vim.api.nvim_create_namespace("ColorHint")

	M.setup_autocmds()
	M.setup_commands()

	-- Initial highlight with delay to avoid startup slowdown
	vim.defer_fn(function()
		if M.is_filetype_enabled() and M.is_file_size_ok() then
			M.highlight_buffer()
		end
	end, 100)
end

-- IMPROVED: More efficient autocmds
function M.setup_autocmds()
	local group = vim.api.nvim_create_augroup("ColorHint", { clear = true })

	-- Initial buffer load
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = function(ev)
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				M.highlight_buffer(ev.buf)
			end
		end,
	})

	-- Filetype changes
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(ev)
			if M.is_filetype_enabled() then
				if M.is_file_size_ok() then
					M.highlight_buffer(ev.buf)
				end
			else
				vim.api.nvim_buf_clear_namespace(ev.buf, M.ns_id, 0, -1)
			end
		end,
	})

	-- IMPROVED: Debounced updates on text changes
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(ev)
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				M.schedule_update(ev.buf)
			end
		end,
	})

	-- Insert leave - immediate update
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function(ev)
			if M.is_filetype_enabled() and M.is_file_size_ok() then
				-- Cancel any pending updates
				if M.timer then
					vim.loop.timer_stop(M.timer)
				end
				M.highlight_buffer(ev.buf)
			end
		end,
	})

	-- LSP attach
	if get_config().options.enable_lsp then
		vim.api.nvim_create_autocmd("LspAttach", {
			group = group,
			callback = function(ev)
				M.highlight_with_lsp(ev.buf, M.ns_id)
			end,
		})
	end

	-- OPTIMIZATION: Only update visible content on scroll
	vim.api.nvim_create_autocmd("WinScrolled", {
		group = group,
		callback = function()
			-- Only update if enough time has passed
			local bufnr = vim.api.nvim_get_current_buf()
			local last = M.last_update[bufnr] or 0
			local now = vim.loop.now()

			if now - last > 200 then -- 200ms throttle
				if M.is_filetype_enabled() and M.is_file_size_ok() then
					M.highlight_visible_range(bufnr)
				end
			end
		end,
	})

	-- Cleanup on buffer unload
	vim.api.nvim_create_autocmd("BufUnload", {
		group = group,
		callback = function(ev)
			M.positions_cache[ev.buf] = nil
			M.last_update[ev.buf] = nil
		end,
	})
end

-- IMPROVED: Better command structure
function M.setup_commands()
	vim.api.nvim_create_user_command("ColorHint", function(opts)
		local arg = string.lower(opts.fargs[1] or "")

		if arg == "on" or arg == "enable" then
			M.enable()
		elseif arg == "off" or arg == "disable" then
			M.disable()
		elseif arg == "toggle" then
			M.toggle()
		elseif arg == "refresh" or arg == "reload" then
			M.highlight_buffer()
		elseif arg == "clear" then
			vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
		elseif arg == "status" or arg == "isactive" then
			M.is_active()
		else
			get_utils().notify("Unknown command. Use: On, Off, Toggle, Refresh, Clear, Status", "warn")
		end
	end, {
		nargs = 1,
		complete = function()
			return { "On", "Off", "Toggle", "Refresh", "Clear", "Status" }
		end,
		desc = "Control ColorHint highlighting",
	})
end

-- File size check
function M.is_file_size_ok()
	local cfg = get_config()
	local max_size = cfg.options.max_file_size
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

-- IMPROVED: Filetype validation with caching
local filetype_cache = {}
function M.is_filetype_enabled()
	if not M.enabled then
		return false
	end

	local cfg = get_config()
	local ft = vim.bo.filetype
	local buftype = vim.bo.buftype

	-- Check cache
	local cache_key = ft .. ":" .. buftype
	if filetype_cache[cache_key] ~= nil then
		return filetype_cache[cache_key]
	end

	-- Check excluded buftypes
	if cfg.options.exclude_buftypes then
		for _, excluded in ipairs(cfg.options.exclude_buftypes) do
			if buftype == excluded then
				filetype_cache[cache_key] = false
				return false
			end
		end
	end

	-- Check excluded filetypes
	if cfg.options.exclude_filetypes then
		for _, excluded in ipairs(cfg.options.exclude_filetypes) do
			if ft == excluded then
				filetype_cache[cache_key] = false
				return false
			end
		end
	end

	-- Check enabled filetypes
	local result = false
	if cfg.options.enabled_filetypes then
		for _, enabled in ipairs(cfg.options.enabled_filetypes) do
			if enabled == "*" or enabled == ft then
				result = true
				break
			end
		end
	end

	filetype_cache[cache_key] = result
	return result
end

-- NEW: Highlight only visible range for better performance
function M.highlight_visible_range(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local win = vim.fn.bufwinid(bufnr)
	if win == -1 then
		return
	end

	-- Get visible range
	local top = vim.fn.line("w0", win) - 1
	local bot = vim.fn.line("w$", win)

	-- Add buffer for smooth scrolling
	top = math.max(0, top - 10)
	bot = bot + 10

	-- Clear and re-highlight visible range
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, top, bot)

	local lines = vim.api.nvim_buf_get_lines(bufnr, top, bot, false)
	local parse = get_parser()
	local render = get_renderer()

	for i, line in ipairs(lines) do
		if line and #line > 0 then
			local colors = parse.parse_line(line)
			for _, color_info in ipairs(colors) do
				render.render_color(bufnr, M.ns_id, top + i - 1, color_info)
			end
		end
	end

	M.last_update[bufnr] = vim.loop.now()
end

-- IMPROVED: Main highlighting with incremental updates
function M.highlight_buffer(bufnr)
	if not M.enabled then
		return
	end

	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
	M.positions_cache[bufnr] = {}

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local parse = get_parser()
	local render = get_renderer()

	-- OPTIMIZATION: Process in chunks to avoid blocking
	local chunk_size = 100
	local function process_chunk(start_line)
		local end_line = math.min(start_line + chunk_size, #lines)

		for i = start_line, end_line do
			local line = lines[i]
			if line and #line > 0 then
				local colors = parse.parse_line(line)

				for _, color_info in ipairs(colors) do
					render.render_color(bufnr, M.ns_id, i - 1, color_info)

					-- Cache positions
					table.insert(M.positions_cache[bufnr], {
						row = i - 1,
						start_column = color_info.start,
						end_column = color_info.finish,
						value = color_info.color,
					})
				end
			end
		end

		-- Schedule next chunk if there are more lines
		if end_line < #lines then
			vim.schedule(function()
				process_chunk(end_line + 1)
			end)
		else
			-- Done - update LSP if enabled
			if get_config().options.enable_lsp then
				M.highlight_with_lsp(bufnr, M.ns_id)
			end

			M.last_update[bufnr] = vim.loop.now()
		end
	end

	-- Start processing
	process_chunk(1)
end

-- LSP integration
function M.highlight_with_lsp(bufnr, ns_id)
	local param = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
	local clients = M.get_lsp_clients(bufnr)

	for _, client in pairs(clients) do
		if client.supports_method("textDocument/documentColor", { bufnr = bufnr }) then
			client.request("textDocument/documentColor", param, function(_, response)
				if response then
					M.highlight_lsp_document_color(response, bufnr, ns_id)
				end
			end, bufnr)
		end
	end
end

-- IMPROVED: LSP color highlighting with validation
function M.highlight_lsp_document_color(response, bufnr, ns_id)
	if not response or #response == 0 then
		return
	end

	local positions = M.positions_cache[bufnr] or {}
	local render = get_renderer()

	for _, match in pairs(response) do
		local r = (match.color.red or 0) * 255
		local g = (match.color.green or 0) * 255
		local b = (match.color.blue or 0) * 255
		local a = (match.color.alpha or 1) * 255

		local value = string.format("#%02x%02x%02x", r, g, b)
		local range = match.range
		local row = range.start.line
		local start_col = range.start.character
		local end_col = range["end"].character

		-- Check if already highlighted
		local already_highlighted = false
		for _, pos in ipairs(positions) do
			if
				pos.row == row
				and pos.start_column == start_col
				and pos.end_column == end_col
				and pos.value == value
			then
				already_highlighted = true
				break
			end
		end

		if not already_highlighted then
			render.render_color(bufnr, ns_id, row, {
				start = start_col,
				finish = end_col,
				color = value,
				format = "lsp",
			})

			table.insert(positions, {
				row = row,
				start_column = start_col,
				end_column = end_col,
				value = value,
			})
		end
	end

	M.positions_cache[bufnr] = positions
end

-- Get LSP clients (compatibility wrapper)
function M.get_lsp_clients(bufnr, client_name)
	local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
	return get_clients({ bufnr = bufnr, name = client_name })
end

-- IMPROVED: Debounced scheduling with mode awareness
function M.schedule_update(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if M.timer then
		vim.loop.timer_stop(M.timer)
	end

	if not M.timer then
		M.timer = vim.loop.new_timer()
	end

	-- Adaptive delay based on mode
	local mode = vim.fn.mode()
	local cfg = get_config()
	local delay = (mode == "i" or mode == "R") and 250 or cfg.options.update_delay

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
	M.enabled = not M.enabled
	local u = get_utils()

	if M.enabled then
		M.highlight_buffer()
		u.notify("ColorHint enabled", "info")
	else
		vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
		u.notify("ColorHint disabled", "info")
	end
end

-- Enable highlighting
function M.enable()
	M.enabled = true
	M.highlight_buffer()
	get_utils().notify("ColorHint enabled", "info")
end

-- Disable highlighting
function M.disable()
	M.enabled = false
	vim.api.nvim_buf_clear_namespace(0, M.ns_id, 0, -1)
	get_utils().notify("ColorHint disabled", "info")
end

-- Status check
function M.is_active()
	local msg = M.enabled and "ColorHint is active" or "ColorHint is inactive"
	get_utils().notify(msg, "info")
end

return M
