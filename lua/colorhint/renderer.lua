local M = {}
local config = require("colorhint.config")
local colors = require("colorhint.colors")

-- Cache for highlight groups (key = uppercase hex without #)
M.hl_cache = {}

-- Create or get cached highlight group
-- @param hex string|nil   e.g. "#ff0000" or nil (in which case we return early)
function M.get_highlight_group(hex)
	-- Safety guard – if for any reason we get nil or empty string, skip rendering this color
	if not hex or hex == "" then
		return { fg = "Normal", bg = "Normal", virtual = "Normal" }
	end

	local cache_key = hex:gsub("^#", ""):upper()

	if M.hl_cache[cache_key] then
		return M.hl_cache[cache_key]
	end

	-- Convert hex → r,g,b[,a]
	local r, g, b, a = colors.hex_to_rgb(hex)

	-- Handle transparency by blending with white background
	if a and a < 255 then
		local alpha = a / 255
		r = math.floor(r * alpha + 255 * (1 - alpha))
		g = math.floor(g * alpha + 255 * (1 - alpha))
		b = math.floor(b * alpha + 255 * (1 - alpha))
	end

	local bg_hex = colors.rgb_to_hex(r, g, b)

	-- Choose best foreground (black or white) for readability
	local fg_hex = colors.get_foreground_color_from_hex_color(bg_hex)

	local hl_names = {
		fg = "ColorHint_" .. cache_key .. "_Fg",
		bg = "ColorHint_" .. cache_key .. "_Bg",
		virtual = "ColorHint_" .. cache_key .. "_Virtual",
	}

	vim.api.nvim_set_hl(0, hl_names.fg, { fg = bg_hex })
	vim.api.nvim_set_hl(0, hl_names.bg, { bg = bg_hex, fg = fg_hex })
	vim.api.nvim_set_hl(0, hl_names.virtual, { fg = bg_hex })

	M.hl_cache[cache_key] = hl_names
	return hl_names
end

-- Render a single color in the buffer
function M.render_color(bufnr, ns_id, row, color_info)
	-- Defensive: sometimes color_info.color can be nil (e.g. failed conversion)
	if not color_info or not color_info.color then
		return
	end

	local hl_groups = M.get_highlight_group(color_info.color)
	local col_start = color_info.start
	local col_end = color_info.finish
	local render_mode = config.options.render

	--------------------------------------------------------------------
	-- Tailwind classes – special treatment (symbol BEFORE the class)
	--------------------------------------------------------------------
	if color_info.format == "tailwind" then
		if config.options.tailwind_render_background and (render_mode == "background" or render_mode == "both") then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
				end_col = col_end,
				hl_group = hl_groups.bg,
				priority = 100,
			})
		end

		if render_mode == "virtual" or render_mode == "both" then
			local symbol = config.options.virtual_symbol or "■ "
			local prefix = config.options.virtual_symbol_prefix or " "

			vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
				virt_text = { { prefix, "Normal" }, { symbol, hl_groups.virtual } },
				virt_text_pos = "inline",
				priority = 102,
			})
		end

		return -- Tailwind only gets the before-symbol, nothing else
	end

	--------------------------------------------------------------------
	-- All other color formats (hex, rgb, hsl, oklch, lsp, named, etc.)
	--------------------------------------------------------------------
	if render_mode == "background" or render_mode == "both" then
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
			end_col = col_end,
			hl_group = hl_groups.bg,
			priority = 100,
		})
	end

	if render_mode == "foreground" then
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
			end_col = col_end,
			hl_group = hl_groups.fg,
			priority = 100,
		})
	end

	if render_mode == "underline" then
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
			end_col = col_end,
			underline = true,
			special = color_info.color,
			priority = 100,
		})
	end

	--------------------------------------------------------------------
	-- Virtual text preview (before / after / both)
	--------------------------------------------------------------------
	if render_mode == "virtual" or render_mode == "both" then
		local symbol = config.options.virtual_symbol or "■ "
		local pos = config.options.virtual_symbol_position or "before"
		local suffix = config.options.virtual_symbol_suffix or " "
		local prefix = config.options.virtual_symbol_prefix or " "

		if pos == "before" or pos == "both" then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
				virt_text = { { symbol, hl_groups.virtual }, { suffix, "Normal" } },
				virt_text_pos = "inline",
				priority = 101,
			})
		end

		if pos == "after" or pos == "both" then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_end, {
				virt_text = { { prefix, "Normal" }, { symbol, hl_groups.virtual } },
				virt_text_pos = "inline",
				priority = 101,
			})
		end
	end
end

function M.clear_cache()
	M.hl_cache = {}
end

return M
