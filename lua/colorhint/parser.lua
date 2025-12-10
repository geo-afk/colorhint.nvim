local M = {}
local config = require("colorhint.config")
local colors = require("colorhint.colors")
local tailwind = require("colorhint.color.tailwind")

-- Priority map for different color formats
local PRIORITY_MAP = {
	tailwind = 5,
	rgb = 4,
	rgba = 4,
	hsl = 4,
	hsla = 4,
	oklch = 4,
	hex = 3,
	named = 1,
}

-- Remove overlapping colors, keeping higher priority ones
local function remove_overlaps(color)
	if #color == 0 then
		return color
	end

	-- Sort by start position, then by priority (higher first)
	table.sort(colors, function(a, b)
		if a.start == b.start then
			return (a.priority or 0) > (b.priority or 0)
		end
		return a.start < b.start
	end)

	local result = {}
	local last_end = -1

	for _, color in ipairs(colors) do
		-- Only add if it doesn't overlap with previous
		if color.start >= last_end then
			table.insert(result, color)
			last_end = color.finish
		end
	end

	return result
end

-- Check if a color match is in a valid context
local function is_valid_context(line, start_pos, finish_pos, color_format)
	-- SIMPLIFIED: Just check for context_aware flag, if disabled return true
	if not config.options.context_aware then
		return true
	end

	local ft = vim.bo.filetype

	-- Get text before the match
	local before = line:sub(1, start_pos)

	-- For named colors, avoid matching object keys
	if color_format == "named" then
		-- Check if this looks like a key in an object/map
		if before:match("%[%s*[\"']?$") or before:match("%{%s*[\"']?$") then
			return false
		end

		local after = line:sub(finish_pos + 1)
		if after:match("^%s*:") then
			return false
		end
	end

	-- For HTML, be very permissive - basically accept everything
	if ft == "html" or ft == "vue" or ft == "svelte" or ft == "astro" then
		return true -- Accept all colors in HTML files
	end

	-- For CSS, colors should be after property colon or in function
	if ft == "css" or ft == "scss" or ft == "sass" or ft == "less" then
		local in_css_value = before:match("%:%s*") ~= nil
		local in_function = before:match("%(%s*[^%)]*$") ~= nil
		return in_css_value or in_function or color_format == "named"
	end

	-- For JS/TS, colors typically in strings or Tailwind classes
	if ft == "javascript" or ft == "typescript" or ft == "javascriptreact" or ft == "typescriptreact" then
		local in_string = (before:match("[\"'][^\"']*$") or before:match("`[^`]*$")) ~= nil
		return in_string or color_format == "tailwind"
	end

	-- For Lua/Python, colors typically in strings
	if ft == "lua" or ft == "python" then
		local in_string = (before:match("[\"'][^\"']*$") or before:match("'[^']*$")) ~= nil
		return in_string
	end

	return true -- Allow in other filetypes
end

-- Main parsing function
function M.parse_line(line)
	local all_colors = {}

	-- Parse in priority order (highest priority first)

	-- 1. Tailwind classes (highest priority - semantic units)
	if config.options.enable_tailwind then
		local tw_colors = tailwind.parse_tailwind(line)
		for _, color in ipairs(tw_colors) do
			color.priority = PRIORITY_MAP.tailwind
			table.insert(all_colors, color)
		end
	end

	-- 2. Function formats (rgb, hsl, oklch)
	if config.options.enable_rgb or config.options.enable_rgba then
		local rgb_colors = M.parse_rgb(line)
		for _, color in ipairs(rgb_colors) do
			color.priority = PRIORITY_MAP[color.format]
			table.insert(all_colors, color)
		end
	end

	if config.options.enable_hsl or config.options.enable_hsla then
		local hsl_colors = M.parse_hsl(line)
		for _, color in ipairs(hsl_colors) do
			color.priority = PRIORITY_MAP[color.format]
			table.insert(all_colors, color)
		end
	end

	if config.options.enable_oklch then
		local oklch_colors = M.parse_oklch(line)
		for _, color in ipairs(oklch_colors) do
			color.priority = PRIORITY_MAP.oklch
			table.insert(all_colors, color)
		end
	end

	-- 3. Hex colors
	if config.options.enable_hex then
		local hex_colors = M.parse_hex(line)
		for _, color in ipairs(hex_colors) do
			color.priority = PRIORITY_MAP.hex
			table.insert(all_colors, color)
		end
	end

	-- 4. Named colors (lowest priority - most ambiguous)
	local ft = vim.bo.filetype
	local overrides = config.options.filetype_overrides[ft] or {}
	local enable_named = config.options.enable_named_colors
	if overrides.enable_named_colors ~= nil then
		enable_named = overrides.enable_named_colors
	end

	if enable_named then
		local named_colors = M.parse_named_colors(line)
		for _, color in ipairs(named_colors) do
			color.priority = PRIORITY_MAP.named
			table.insert(all_colors, color)
		end
	end

	-- Filter by context validity
	local valid_colors = {}
	for _, color in ipairs(all_colors) do
		if is_valid_context(line, color.start, color.finish, color.format) then
			table.insert(valid_colors, color)
		end
	end

	-- Remove overlaps
	return remove_overlaps(valid_colors)
end

-- Parse hex colors with better boundary detection
function M.parse_hex(line)
	local results = {}

	-- Long hex: #RRGGBB or #RRGGBBAA
	local idx = 1
	while idx <= #line do
		local start_pos, end_pos, hex = line:find("(#%x%x%x%x%x%x%x?%x?)", idx)
		if not start_pos then
			break
		end

		local len = end_pos - start_pos + 1
		if len == 7 or len == 9 then
			-- Check it's not part of a longer hex string
			local after_char = line:sub(end_pos + 1, end_pos + 1)
			if not after_char:match("%x") then
				table.insert(results, {
					color = hex,
					start = start_pos - 1,
					finish = end_pos,
					format = "hex",
				})
				idx = end_pos + 1
			else
				idx = start_pos + 1
			end
		else
			idx = start_pos + 1
		end
	end

	-- Short hex: #RGB (only if enabled)
	if config.options.enable_short_hex then
		idx = 1
		while idx <= #line do
			-- Match #XXX followed by non-hex character
			local start_pos, end_pos, hex = line:find("(#%x%x%x)([^%x])", idx)
			if not start_pos then
				-- Try at end of line
				start_pos, end_pos, hex = line:find("(#%x%x%x)$", idx)
				if not start_pos then
					break
				end
			end

			-- Avoid matching if already in results
			local is_duplicate = false
			for _, r in ipairs(results) do
				if start_pos >= r.start + 1 and end_pos - 1 <= r.finish + 1 then
					is_duplicate = true
					break
				end
			end

			if not is_duplicate then
				table.insert(results, {
					color = hex,
					start = start_pos - 1,
					finish = end_pos - 1,
					format = "hex",
				})
			end

			idx = end_pos
		end
	end

	return results
end

-- Parse RGB/RGBA colors with better validation
function M.parse_rgb(line)
	local results = {}
	local offset = 0

	while true do
		-- Match rgba? with various separators
		local start_idx, end_idx, r, g, b, a = line:find(
			"rgba?%s*%((%d+%.?%d*)%s*[,/]?%s*(%d+%.?%d*)%s*[,/]?%s*(%d+%.?%d*)%s*[,/]?%s*([%d%.]*)",
			offset + 1
		)

		if not start_idx then
			break
		end

		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		a = a ~= "" and tonumber(a) or 1

		-- Validate ranges
		if r and g and b and r <= 255 and g <= 255 and b <= 255 then
			local hex = colors.rgb_to_hex(r, g, b, a)
			local format = (a and a < 1) and "rgba" or "rgb"

			table.insert(results, {
				color = hex,
				start = start_idx - 1,
				finish = end_idx,
				format = format,
			})
		end

		offset = end_idx
	end

	return results
end

-- Parse HSL/HSLA colors
function M.parse_hsl(line)
	local results = {}
	local offset = 0

	while true do
		local start_idx, end_idx, h, s, l, a = line:find(
			"hsla?%s*%((%d+%.?%d*)%s*[,/]?%s*(%d+%.?%d*)%%?%s*[,/]?%s*(%d+%.?%d*)%%?%s*[,/]?%s*([%d%.]*)",
			offset + 1
		)

		if not start_idx then
			break
		end

		h, s, l = tonumber(h), tonumber(s), tonumber(l)
		a = a ~= "" and tonumber(a) or 1

		if h and s and l and h <= 360 and s <= 100 and l <= 100 then
			local r, g, b = colors.hsl_to_rgb(h, s, l)
			local hex = colors.rgb_to_hex(r, g, b, a)
			local format = (a and a < 1) and "hsla" or "hsl"

			table.insert(results, {
				color = hex,
				start = start_idx - 1,
				finish = end_idx,
				format = format,
			})
		end

		offset = end_idx
	end

	return results
end

-- Parse OKLCH colors
function M.parse_oklch(line)
	local results = {}
	local offset = 0

	while true do
		-- oklch(L C H) or oklch(L C H / A)
		local start_idx, end_idx, l, c, h, a =
			line:find("oklch%s*%(%s*([%d%.]+)%%?%s+([%d%.]+)%s+([%d%.]+)deg?%s*/?%s*([%d%.]*)", offset + 1)

		if not start_idx then
			break
		end

		l = tonumber(l)
		c = tonumber(c)
		h = tonumber(h)
		a = a ~= "" and tonumber(a) or 1

		if l and c and h then
			-- Convert L from percentage if needed
			if l > 1 then
				l = l / 100
			end

			local r, g, b = colors.oklch_to_rgb(l, c, h)
			local hex = colors.rgb_to_hex(r, g, b, a)

			table.insert(results, {
				color = hex,
				start = start_idx - 1,
				finish = end_idx,
				format = "oklch",
			})
		end

		offset = end_idx
	end

	return results
end

-- Parse named CSS colors with word boundaries
function M.parse_named_colors(line)
	local results = {}

	for name, hex in pairs(colors.NAMED_COLORS) do
		-- Use word boundary pattern
		local pattern = "%f[%a]" .. name .. "%f[%A]"
		local start_idx = 1

		while true do
			local start, finish = line:find(pattern, start_idx, false)
			if not start then
				break
			end

			table.insert(results, {
				color = hex,
				start = start - 1,
				finish = finish,
				format = "named",
			})

			start_idx = finish + 1
		end
	end

	return results
end

return M
