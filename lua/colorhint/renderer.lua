local M = {}
local config = require("colorhint.config")
local colors = require("colorhint.colors")

-- Cache for highlight groups
M.hl_cache = {}

-- Create or get cached highlight group
function M.get_highlight_group(hex)
	local cache_key = hex:gsub("#", ""):upper()

	if M.hl_cache[cache_key] then
		return M.hl_cache[cache_key]
	end

	local r, g, b, a = colors.hex_to_rgb(hex)

	-- Handle alpha transparency by blending with white
	if a < 255 then
		local alpha = a / 255
		local bg_r, bg_g, bg_b = 255, 255, 255
		r = math.floor(r * alpha + bg_r * (1 - alpha))
		g = math.floor(g * alpha + bg_g * (1 - alpha))
		b = math.floor(b * alpha + bg_b * (1 - alpha))
	end

	local bg_hex = colors.rgb_to_hex(r, g, b)
	local use_dark = colors.should_use_dark_text(r, g, b)
	local fg_hex = use_dark and "#000000" or "#ffffff"

	local hl_names = {
		fg = "ColorHint_" .. cache_key .. "_Fg",
		bg = "ColorHint_" .. cache_key .. "_Bg",
		virtual = "ColorHint_" .. cache_key .. "_Virtual",
	}

	-- Create highlight groups
	vim.api.nvim_set_hl(0, hl_names.fg, { fg = bg_hex })
	vim.api.nvim_set_hl(0, hl_names.bg, { bg = bg_hex, fg = fg_hex })
	vim.api.nvim_set_hl(0, hl_names.virtual, { fg = bg_hex })

	M.hl_cache[cache_key] = hl_names
	return hl_names
end

-- Render a single color in the buffer
function M.render_color(bufnr, ns_id, row, color_info)
	local hl_groups = M.get_highlight_group(color_info.color)
	local col_start = color_info.start
	local col_end = color_info.finish

	local render_mode = config.options.render

	-- Apply text highlighting
	if render_mode == "background" or render_mode == "both" then
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
			end_col = col_end,
			hl_group = hl_groups.bg,
			priority = 100,
		})
	elseif render_mode == "foreground" then
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
			end_col = col_end,
			hl_group = hl_groups.fg,
			priority = 100,
		})
	end

	-- Add virtual text color preview
	if render_mode == "virtual" or render_mode == "both" then
		local symbol = config.options.virtual_symbol
		local suffix = config.options.virtual_symbol_suffix

		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_end, {
			virt_text = { { symbol .. suffix, hl_groups.virtual } },
			virt_text_pos = "inline",
			priority = 100,
		})
	end
end

-- Clear all cached highlight groups
function M.clear_cache()
	M.hl_cache = {}
end

return M
