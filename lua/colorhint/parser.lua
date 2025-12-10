local M = {}
local config = require("colorhint.config")
local colors = require("colorhint.colors")
local tailwind = require("colorhint.color.tailwind")

-- Priority map for different color formats (unchanged)
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

-- Borrowed patterns
local RGB_REGEX = "rgba?[(]+" .. string.rep("%s*%d+%s*", 3, "[,%s]") .. "[,%s/]?%s*%d*%.?%d*%%?%s*[)]+"
local HEX_REGEX = "#%x%x%x+%f[^%w_-]"
local HEX_0X_REGEX = "%f[%w_]0x%x%x%x+%f[^%w_]"
local HSL_REGEX = "hsla?[(]+"
	.. string.rep("%s*%d*%.?%d+%%?d?e?g?t?u?r?n?%s*", 3, "[,%s]")
	.. "[%s,/]?%s*%d*%.?%d*%%?%s*[)]+"
local HSL_WITHOUT_FUNC_REGEX = ":" .. string.rep("%s*%d*%.?%d+%%?d?e?g?t?u?r?n?%s*", 3, "[,%s]")
local VAR_REGEX = "%-%-[%d%a-_]+"
local VAR_DECLARATION_REGEX = VAR_REGEX .. ":%s*" .. HEX_REGEX
local VAR_USAGE_REGEX = "var%(" .. VAR_REGEX .. "%)"
local ANSI_REGEX = "\\033%[%d;%d%dm"

-- Remove overlapping colors, keeping higher priority ones (unchanged)
local function remove_overlaps(colors)
	if #colors == 0 then
		return colors
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

-- Check if a color match is in a valid context (unchanged)
local function is_valid_context(line, start_pos, finish_pos, color_format)
	if not config.options.context_aware then
		return true -- Context checking disabled
	end

	local ft = vim.bo.filetype

	-- Get text before the match
	local before = line:sub(1, start_pos)

	if color_format == "named" then
		if before:match("%[%s*[\"']?$$ ") or before:match("%{%s*[\"']? $$") then -- Removed the colon pattern here
			return false -- Likely a key, not a value
		end

		local after = line:sub(finish_pos + 1)
		if after:match("^%s*:") then
			return false -- Likely a key if followed by colon
		end
	end

	-- Check for different contexts based on filetype
	if ft == "html" or ft == "vue" or ft == "svelte" or ft == "astro" then
		-- In HTML-like files, colors should be in attributes or style
		local in_attribute = before:match("[a-zA-Z%-]+%s*=%s*[\"']$") ~= nil
		local in_style = before:match("style%s*=%s*[\"'][^\"']*$") ~= nil
		return in_attribute or in_style
	elseif ft == "css" or ft == "scss" or ft == "sass" or ft == "less" then
		-- In CSS, colors should be after property colon or in function
		local in_css_value = before:match("%:%s*$") ~= nil
		local in_function = before:match("%(%s*[^%)]*$") ~= nil
		return in_css_value or in_function or color_format == "named"
	elseif ft == "javascript" or ft == "typescript" or ft == "javascriptreact" or ft == "typescriptreact" then
		-- In JS/TS, colors typically in strings or Tailwind classes
		local in_string = (before:match("[\"'][^\"']*$") or before:match("`[^`]*$")) ~= nil
		return in_string or color_format == "tailwind"
	elseif ft == "lua" or ft == "python" then
		-- In Lua/Python, colors typically in strings
		local in_string = (before:match("[\"'][^\"']*$") or before:match("'[^']*$")) ~= nil
		return in_string
	end

	return true -- Allow in other filetypes
end

-- Main parsing function (updated with borrowed patterns)
function M.parse_line(line)
	local all_colors = {}

	-- Parse in priority order (highest priority first)
	-- This helps with overlap detection

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

	-- New: ANSI
	if config.options.enable_ansi then
		local ansi_colors = M.parse_ansi(line)
		for _, color in ipairs(ansi_colors) do
			color.priority = PRIORITY_MAP.named
			table.insert(all_colors, color)
		end
	end

	-- New: Custom colors
	local custom_colors = M.parse_custom_colors(line, config.options.custom_colors)
	for _, color in ipairs(custom_colors) do
		color.priority = PRIORITY_MAP.named
		table.insert(all_colors, color)
	end

	-- New: Var colors
	local var_colors = M.parse_var_colors(line)
	for _, color in ipairs(var_colors) do
		color.priority = PRIORITY_MAP.named
		table.insert(all_colors, color)
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

-- Parse hex colors with better boundary detection (updated with borrowed regex)
function M.parse_hex(line)
	local results = {}

	-- Long hex: #RRGGBB or #RRGGBBAA
	local idx = 1
	while idx <= #line do
		local start_pos, end_pos, hex = line:find(HEX_REGEX, idx)
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

-- Parse RGB/RGBA colors with better validation (updated with borrowed regex)
function M.parse_rgb(line)
	local results = {}
	local offset = 0

	while true do
		local start_idx, end_idx = line:find(RGB_REGEX, offset + 1)
		if not start_idx then
			break
		end

		local color = line:sub(start_idx, end_idx)
		local value = M.get_color_value(color, 0, config.options.custom_colors, config.options.enable_short_hex)
		if value then
			table.insert(results, {
				color = value,
				start = start_idx - 1,
				finish = end_idx,
				format = "rgb",
			})
		end

		offset = end_idx
	end

	return results
end

-- Parse HSL/HSLA colors (updated with borrowed regex and hsl without func)
function M.parse_hsl(line)
	local results = {}
	local offset = 0

	while true do
		local start_idx, end_idx = line:find(HSL_REGEX, offset + 1)
		if not start_idx then
			break
		end

		local color = line:sub(start_idx, end_idx)
		local value = M.get_color_value(color, 0, config.options.custom_colors, config.options.enable_short_hex)
		if value then
			table.insert(results, {
				color = value,
				start = start_idx - 1,
				finish = end_idx,
				format = "hsl",
			})
		end

		offset = end_idx
	end

	-- Borrowed: HSL without func
	offset = 0
	while true do
		local start_idx, end_idx = line:find(HSL_WITHOUT_FUNC_REGEX, offset + 1)
		if not start_idx then
			break
		end

		local color = line:sub(start_idx, end_idx)
		local value = M.get_color_value(color, 0, config.options.custom_colors, config.options.enable_short_hex)
		if value then
			table.insert(results, {
				color = value,
				start = start_idx - 1,
				finish = end_idx,
				format = "hsl",
			})
		end

		offset = end_idx
	end

	return results
end

-- Parse OKLCH colors (unchanged)
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

-- Parse named CSS colors with word boundaries (unchanged)
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

-- New: Parse ANSI
function M.parse_ansi(line)
	local results = {}
	local offset = 0

	while true do
		local start_idx, end_idx = line:find(ANSI_REGEX, offset + 1)
		if not start_idx then
			break
		end

		local color = line:sub(start_idx, end_idx)
		local value = colors.ANSI_COLORS[string.match(color, "([0-9;]+)m")] -- Borrowed matching
		if value then
			table.insert(results, {
				color = value,
				start = start_idx - 1,
				finish = end_idx,
				format = "ansi",
			})
		end

		offset = end_idx
	end

	return results
end

-- New: Parse custom colors (borrowed)
function M.parse_custom_colors(line, custom_colors)
	local results = {}
	for _, custom in ipairs(custom_colors) do
		local pattern = "%f[%a]" .. custom.label:gsub("%%", "") .. "%f[%A]"
		local start_idx = 1
		while true do
			local start, finish = line:find(pattern, start_idx, false)
			if not start then
				break
			end
			table.insert(results, {
				color = custom.color,
				start = start - 1,
				finish = finish,
				format = "custom",
			})
			start_idx = finish + 1
		end
	end
	return results
end

-- New: Parse var colors (borrowed)
function M.parse_var_colors(line)
	local results = {}
	local offset = 0

	while true do
		local start_idx, end_idx = line:find(VAR_USAGE_REGEX, offset + 1)
		if not start_idx then
			break
		end

		local color = line:sub(start_idx, end_idx)
		local value = M.get_css_var_color(color, 0) -- Borrowed function below
		if value then
			table.insert(results, {
				color = value,
				start = start_idx - 1,
				finish = end_idx,
				format = "var",
			})
		end

		offset = end_idx
	end

	return results
end

-- Borrowed: Get color value (unified converter)
function M.get_color_value(color, row_offset, custom_colors, enable_short_hex)
	if enable_short_hex and (color:match(HEX_REGEX) and #color == 4) then
		return colors.rgb_to_hex(
			tonumber(color:sub(2, 2) .. color:sub(2, 2), 16),
			tonumber(color:sub(3, 3) .. color:sub(3, 3), 16),
			tonumber(color:sub(4, 4) .. color:sub(4, 4), 16)
		)
	end

	if enable_short_hex and (color:match(HEX_REGEX) and #color == 5) then
		return colors.rgb_to_hex(
			tonumber(color:sub(2, 2) .. color:sub(2, 2), 16),
			tonumber(color:sub(3, 3) .. color:sub(3, 3), 16),
			tonumber(color:sub(4, 4) .. color:sub(4, 4), 16)
		)
	end

	if color:match(HEX_REGEX) and #color == 9 then
		return color:sub(1, 7)
	end

	if color:match(RGB_REGEX) then
		local rgb_table = {}
		for num in color:gmatch("%d+") do
			table.insert(rgb_table, num)
		end
		if #rgb_table >= 3 then
			return colors.rgb_to_hex(rgb_table[1], rgb_table[2], rgb_table[3])
		end
	end

	if color:match(HSL_REGEX) then
		local hsl_table = {}
		for num in color:gmatch("%d*%.?%d+") do
			table.insert(hsl_table, num)
		end
		if #hsl_table >= 3 then
			local rgb = colors.hsl_to_rgb(hsl_table[1], hsl_table[2], hsl_table[3])
			return colors.rgb_to_hex(rgb[1], rgb[2], rgb[3])
		end
	end

	if color:match(HSL_WITHOUT_FUNC_REGEX) then
		local hsl_table = {}
		local clean_color = color:match(":%s*(.+)")
		if clean_color then
			for value in clean_color:gmatch("%d*%.?%d+") do
				table.insert(hsl_table, value)
			end
		end
		if #hsl_table >= 3 then
			local rgb = colors.hsl_to_rgb(hsl_table[1], hsl_table[2], hsl_table[3])
			return colors.rgb_to_hex(rgb[1], rgb[2], rgb[3])
		end
	end

	if color:match("%a+") then
		return colors.NAMED_COLORS[color:match("%a+")]
	end

	if color:match(ANSI_REGEX) then
		local code = color:match("([0-9;]+)m")
		return colors.ANSI_COLORS[code]
	end

	if custom_colors and #custom_colors > 0 then
		for _, custom in ipairs(custom_colors) do
			if color == custom.label:gsub("%%", "") then
				return custom.color
			end
		end
	end

	if color:match(VAR_USAGE_REGEX) then
		return M.get_css_var_color(color, row_offset or 0)
	end

	local hex_color = color:gsub("0x", "#")
	if #hex_color == 7 then
		return hex_color
	end

	return nil
end

-- Borrowed: Get CSS var color
function M.get_css_var_color(color, row_offset)
	local var_name = color:match(VAR_REGEX)
	local var_name_regex = var_name:gsub("%-", "%%-")
	local value_patterns = {
		HEX_REGEX,
		RGB_REGEX,
		HSL_REGEX,
		HSL_WITHOUT_FUNC_REGEX:gsub("^:%s*", ""),
	}
	local var_patterns = {}

	for _, pattern in pairs(value_patterns) do
		table.insert(var_patterns, var_name_regex .. ":%s*" .. pattern)
	end

	-- Simplified position fetch (use vim.fn.search or similar in real impl)
	local var_position = {} -- Placeholder; implement buffer search if needed
	if #var_position > 0 then
		return M.get_color_value(var_position[1].value, row_offset)
	end

	return nil
end

return M
