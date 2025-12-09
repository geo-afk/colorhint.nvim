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

	-- Background / Foreground highlighting
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

	-- Underline mode (Neovim 0.10+ supports colored underlines)
	if render_mode == "underline" then
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col_start, {
			end_col = col_end,
			underline = true,
			special = color_info.color, -- colored underline
			priority = 100,
		})
	end

	-- Virtual text preview (before / after / both)
	if render_mode == "virtual" or render_mode == "both" then
		local symbol = config.options.virtual_symbol or "■"
		local position = config.options.virtual_symbol_position or "before"
		local suffix = config.options.virtual_symbol_suffix or " "
		local prefix = config.options.virtual_symbol_prefix or " "

		local virt_text = {}
		local virt_col = col_start

		if position == "before" or position == "both" then
			table.insert(virt_text, { symbol, hl_groups.virtual })
			table.insert(virt_text, { suffix, "Normal" })
		end

		if position == "after" or position == "both" then
			if position == "both" then
				-- For "both", we place two symbols: one before, one after
				-- So we only add the "after" part here
				virt_col = col_end
				virt_text = { { prefix, "Normal" }, { symbol, hl_groups.virtual } }
			else
				-- Only "after"
				virt_text = { { prefix, "Normal" }, { symbol, hl_groups.virtual } }
				virt_col = col_end
			end
		end

		-- Single extmark for virtual text
		vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, virt_col, {
			virt_text = virt_text,
			virt_text_pos = "inline",
			priority = 101, -- Slightly above background
		})
	end
end

-- Clear all cached highlight groups
function M.clear_cache()
	M.hl_cache = {}
end

return M
