local M = {}
local config = require("colorhint.config")
local colors = require("colorhint.colors")
local tailwind = require("colorhint.color.tailwind")

-- Priority map (unchanged)
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

-- IMPROVED: More accurate regex patterns
local RGB_REGEX = "rgba?%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+%s*[,/]?%s*[%d%.]*%%?%s*%)"
local HEX_REGEX = "#%x%x%x+%f[^%w_-]"
local HSL_REGEX = "hsla?%s*%(%s*[%d%.]+%s*,%s*[%d%.]+%%?%s*,%s*[%d%.]+%%?%s*[,/]?%s*[%d%.]*%%?%s*%)"
local VAR_REGEX = "%-%-[%d%a-_]+"
local VAR_USAGE_REGEX = "var%(" .. VAR_REGEX .. "%)"
local ANSI_REGEX = "\\033%[%d;%d%dm"

-- IMPROVED: More efficient overlap removal with position validation
local function remove_overlaps(color_list)
	if #color_list == 0 then
		return color_list
	end

	-- Sort by start position, then by priority (higher first)
	table.sort(color_list, function(a, b)
		if a.start == b.start then
			return (a.priority or 0) > (b.priority or 0)
		end
		return a.start < b.start
	end)

	local result = {}
	local last_end = -1

	for _, color in ipairs(color_list) do
		-- Validate positions
		if color.start >= 0 and color.finish > color.start and color.start >= last_end then
			table.insert(result, color)
			last_end = color.finish
		end
	end

	return result
end

-- IMPROVED: Better context validation
local function is_valid_context(line, start_pos, finish_pos, color_format)
	if not config.options.context_aware then
		return true
	end

	local ft = vim.bo.filetype
	local before = line:sub(1, start_pos)

	-- Named colors need extra validation
	if color_format == "named" then
		-- Skip if it looks like a key in object/dict
		if before:match("[{,]%s*$") then
			return false
		end

		-- Skip if followed by colon (likely a key)
		local after = line:sub(finish_pos + 1, finish_pos + 2)
		if after:match("^%s*:") then
			return false
		end
	end

	-- HTML-like files
	if ft == "html" or ft == "vue" or ft == "svelte" or ft == "astro" or ft == "htmlangular" then
		local in_attr = before:match("[a-zA-Z%-]+%s*=%s*[\"']$") ~= nil
		local in_style = before:match("style%s*=%s*[\"'][^\"']*$") ~= nil
		local in_class = before:match("class%s*=%s*[\"'][^\"']*$") ~= nil
		return in_attr or in_style or in_class or color_format == "tailwind"
	end

	-- CSS-like files
	if ft == "css" or ft == "scss" or ft == "sass" or ft == "less" then
		local in_value = before:match(":%s*$") ~= nil
		local in_func = before:match("%(%s*[^%)]*$") ~= nil
		return in_value or in_func or color_format == "named"
	end

	-- JS/TS files
	if ft == "javascript" or ft == "typescript" or ft == "javascriptreact" or ft == "typescriptreact" then
		local in_str = (before:match("[\"'][^\"']*$") or before:match("`[^`]*$")) ~= nil
		return in_str or color_format == "tailwind"
	end

	-- Lua/Python
	if ft == "lua" or ft == "python" then
		local in_str = before:match("[\"'][^\"']*$") ~= nil
		return in_str
	end

	return true
end

-- Main parsing function
function M.parse_line(line)
	local all_colors = {}

	-- OPTIMIZATION: Early exit for empty lines
	if not line or #line == 0 then
		return {}
	end

	-- Parse in priority order

	-- 1. Tailwind (highest priority)
	if config.options.enable_tailwind then
		local tw_colors = tailwind.parse_tailwind(line)
		for _, color in ipairs(tw_colors) do
			color.priority = PRIORITY_MAP.tailwind
			table.insert(all_colors, color)
		end
	end

	-- 2. Function formats
	if config.options.enable_rgb or config.options.enable_rgba then
		local rgb_colors = M.parse_rgb(line)
		for _, color in ipairs(rgb_colors) do
			color.priority = PRIORITY_MAP.rgb
			table.insert(all_colors, color)
		end
	end

	if config.options.enable_hsl or config.options.enable_hsla then
		local hsl_colors = M.parse_hsl(line)
		for _, color in ipairs(hsl_colors) do
			color.priority = PRIORITY_MAP.hsl
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

	-- 4. Named colors (lowest priority)
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

	-- ANSI colors
	if config.options.enable_ansi then
		local ansi_colors = M.parse_ansi(line)
		for _, color in ipairs(ansi_colors) do
			color.priority = PRIORITY_MAP.named
			table.insert(all_colors, color)
		end
	end

	-- Custom colors
	local custom_colors = M.parse_custom_colors(line, config.options.custom_colors)
	for _, color in ipairs(custom_colors) do
		color.priority = PRIORITY_MAP.named
		table.insert(all_colors, color)
	end

	-- CSS variables
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

	return remove_overlaps(valid_colors)
end

-- IMPROVED: Better hex parsing with proper boundary detection
function M.parse_hex(line)
	local results = {}
	local idx = 1

	while idx <= #line do
		local start_pos, end_pos, hex = line:find("(#%x%x%x+)%f[%W_]", idx)
		if not start_pos then
			break
		end

		local hex_len = #hex
		-- Valid long hex: #RRGGBB (7) or #RRGGBBAA (9)
		if hex_len == 7 or hex_len == 9 then
			table.insert(results, {
				color = hex,
				start = start_pos - 1,
				finish = end_pos,
				format = "hex",
			})
			idx = end_pos + 1
		-- Short hex: #RGB (4) - only if enabled
		elseif hex_len == 4 and config.options.enable_short_hex then
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
	end

	return results
end

-- IMPROVED: Better RGB parsing
function M.parse_rgb(line)
	local results = {}
	local idx = 1

	while idx <= #line do
		local start_pos, end_pos = line:find(RGB_REGEX, idx)
		if not start_pos then
			break
		end

		local color_str = line:sub(start_pos, end_pos)
		local value = M.get_color_value(color_str, 0, config.options.custom_colors, config.options.enable_short_hex)

		if value then
			table.insert(results, {
				color = value,
				start = start_pos - 1,
				finish = end_pos,
				format = "rgb",
			})
		end

		idx = end_pos + 1
	end

	return results
end

-- IMPROVED: Better HSL parsing
function M.parse_hsl(line)
	local results = {}
	local idx = 1

	while idx <= #line do
		local start_pos, end_pos = line:find(HSL_REGEX, idx)
		if not start_pos then
			break
		end

		local color_str = line:sub(start_pos, end_pos)
		local value = M.get_color_value(color_str, 0, config.options.custom_colors, config.options.enable_short_hex)

		if value then
			table.insert(results, {
				color = value,
				start = start_pos - 1,
				finish = end_pos,
				format = "hsl",
			})
		end

		idx = end_pos + 1
	end

	return results
end

-- OKLCH parsing (unchanged)
function M.parse_oklch(line)
	local results = {}
	local idx = 1

	while idx <= #line do
		local start_pos, end_pos, l, c, h, a =
			line:find("oklch%s*%(%s*([%d%.]+)%%?%s+([%d%.]+)%s+([%d%.]+)deg?%s*/?%s*([%d%.]*)", idx)

		if not start_pos then
			break
		end

		l, c, h = tonumber(l), tonumber(c), tonumber(h)
		a = a ~= "" and tonumber(a) or 1

		if l and c and h then
			if l > 1 then
				l = l / 100
			end

			local r, g, b = colors.oklch_to_rgb(l, c, h)
			local hex = colors.rgb_to_hex(r, g, b, a)

			table.insert(results, {
				color = hex,
				start = start_pos - 1,
				finish = end_pos,
				format = "oklch",
			})
		end

		idx = end_pos + 1
	end

	return results
end

-- IMPROVED: Named colors with better word boundaries
function M.parse_named_colors(line)
	local results = {}

	for name, hex in pairs(colors.NAMED_COLORS) do
		local pattern = "%f[%a]" .. name .. "%f[%A]"
		local idx = 1

		while idx <= #line do
			local start_pos, end_pos = line:find(pattern, idx)
			if not start_pos then
				break
			end

			table.insert(results, {
				color = hex,
				start = start_pos - 1,
				finish = end_pos,
				format = "named",
			})

			idx = end_pos + 1
		end
	end

	return results
end

-- ANSI parsing
function M.parse_ansi(line)
	local results = {}
	local idx = 1

	while idx <= #line do
		local start_pos, end_pos = line:find(ANSI_REGEX, idx)
		if not start_pos then
			break
		end

		local color_str = line:sub(start_pos, end_pos)
		local code = color_str:match("([0-9;]+)m")
		local value = colors.ANSI_COLORS[code]

		if value then
			table.insert(results, {
				color = value,
				start = start_pos - 1,
				finish = end_pos,
				format = "ansi",
			})
		end

		idx = end_pos + 1
	end

	return results
end

-- Custom colors parsing
function M.parse_custom_colors(line, custom_colors)
	local results = {}

	if not custom_colors or #custom_colors == 0 then
		return results
	end

	for _, custom in ipairs(custom_colors) do
		local label = custom.label:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		local pattern = "%f[%a]" .. label .. "%f[%A]"
		local idx = 1

		while idx <= #line do
			local start_pos, end_pos = line:find(pattern, idx)
			if not start_pos then
				break
			end

			table.insert(results, {
				color = custom.color,
				start = start_pos - 1,
				finish = end_pos,
				format = "custom",
			})

			idx = end_pos + 1
		end
	end

	return results
end

-- CSS variables - simplified (full implementation requires buffer scanning)
function M.parse_var_colors(line)
	-- This is a placeholder - full CSS var support requires
	-- scanning the entire buffer for var declarations
	return {}
end

-- IMPROVED: Unified color value converter
function M.get_color_value(color_str, row_offset, custom_colors, enable_short_hex)
	-- Short hex: #RGB -> #RRGGBB
	if enable_short_hex and color_str:match("^#%x%x%x$") then
		local r, g, b = color_str:sub(2, 2), color_str:sub(3, 3), color_str:sub(4, 4)
		return "#" .. r .. r .. g .. g .. b .. b
	end

	-- Long hex with alpha: #RRGGBBAA -> #RRGGBB (strip alpha)
	if color_str:match("^#%x%x%x%x%x%x%x%x$") then
		return color_str:sub(1, 7)
	end

	-- Standard hex
	if color_str:match("^#%x%x%x%x%x%x$") then
		return color_str
	end

	-- RGB/RGBA
	if color_str:match("^rgba?%s*%(") then
		local nums = {}
		for num in color_str:gmatch("%d+") do
			table.insert(nums, tonumber(num))
		end
		if #nums >= 3 then
			return colors.rgb_to_hex(nums[1], nums[2], nums[3])
		end
	end

	-- HSL/HSLA
	if color_str:match("^hsla?%s*%(") then
		local nums = {}
		for num in color_str:gmatch("[%d%.]+") do
			table.insert(nums, tonumber(num))
		end
		if #nums >= 3 then
			local rgb = colors.hsl_to_rgb(nums[1], nums[2], nums[3])
			return colors.rgb_to_hex(rgb[1], rgb[2], rgb[3])
		end
	end

	-- Named colors
	if color_str:match("^%a+$") then
		return colors.NAMED_COLORS[color_str:lower()]
	end

	-- ANSI
	if color_str:match(ANSI_REGEX) then
		local code = color_str:match("([0-9;]+)m")
		return colors.ANSI_COLORS[code]
	end

	-- Custom colors
	if custom_colors then
		for _, custom in ipairs(custom_colors) do
			if color_str == custom.label then
				return custom.color
			end
		end
	end

	-- 0x prefix hex
	if color_str:match("^0x%x%x%x%x%x%x$") then
		return "#" .. color_str:sub(3)
	end

	return nil
end

return M
