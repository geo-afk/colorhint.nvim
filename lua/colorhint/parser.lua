local M = {}
local config = require("colorhint.config")
local colors = require("colorhint.colors")

-- Parse a single line and return all color matches
function M.parse_line(line)
	local all_colors = {}

	if config.options.enable_hex then
		vim.list_extend(all_colors, M.parse_hex(line))
	end

	if config.options.enable_rgb then
		vim.list_extend(all_colors, M.parse_rgb(line))
	end

	if config.options.enable_hsl then
		vim.list_extend(all_colors, M.parse_hsl(line))
	end

	if config.options.enable_oklch then
		vim.list_extend(all_colors, M.parse_oklch(line))
	end

	if config.options.enable_named_colors then
		vim.list_extend(all_colors, M.parse_named_colors(line))
	end

	return all_colors
end

-- Parse hex colors
function M.parse_hex(line)
	local results = {}

	-- Match #rrggbb and #rrggbbaa (non-overlapping)
	for s, e, hex in line:gmatch("()#(%x%x%x%x%x%x%x?%x?)()") do
		if #hex == 6 or #hex == 8 then
			table.insert(results, {
				color = "#" .. hex,
				start = s - 1,
				finish = e - 1,
				format = "hex",
			})
		end
	end

	-- Match #rgb only if not part of longer match
	if config.options.enable_short_hex then
		for s, e, hex in line:gmatch("()#(%x%x%x)([^%x])") do
			local is_inside_long = false
			for _, r in ipairs(results) do
				if s >= r.start + 1 and s <= r.finish then
					is_inside_long = true
					break
				end
			end
			if not is_inside_long then
				table.insert(results, {
					color = "#" .. hex,
					start = s - 1,
					finish = e - 2, -- exclude the non-hex char
					format = "hex",
				})
			end
		end
	end

	return results
end

-- Parse RGB/RGBA colors
function M.parse_rgb(line)
	local results = {}
	local offset = 0

	while true do
		local start_idx, end_idx, r, g, b, a =
			line:find("rgba?%s*%((%d+)%s*[,/]?%s*(%d+)%s*[,/]?%s*(%d+)%s*[,/]?%s*([%d%.]*)", offset + 1)

		if not start_idx then
			break
		end

		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		a = a ~= "" and tonumber(a) or 1

		if r and g and b and r <= 255 and g <= 255 and b <= 255 then
			local hex = colors.rgb_to_hex(r, g, b, a)
			table.insert(results, {
				color = hex,
				start = start_idx - 1,
				finish = end_idx,
				format = "rgb",
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
		local start_idx, end_idx, h, s, l, a =
			line:find("hsla?%s*%((%d+)%s*[,/]?%s*(%d+)%%?%s*[,/]?%s*(%d+)%%?%s*[,/]?%s*([%d%.]*)", offset + 1)

		if not start_idx then
			break
		end

		h, s, l = tonumber(h), tonumber(s), tonumber(l)
		a = a ~= "" and tonumber(a) or 1

		if h and s and l and h <= 360 and s <= 100 and l <= 100 then
			local r, g, b = colors.hsl_to_rgb(h, s, l)
			local hex = colors.rgb_to_hex(r, g, b, a)
			table.insert(results, {
				color = hex,
				start = start_idx - 1,
				finish = end_idx,
				format = "hsl",
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
		-- Pattern matches: oklch(L C H) or oklch(L C H / A)
		-- L: 0-1 or 0%-100%, C: 0-0.4 typically, H: 0-360deg
		local start_idx, end_idx, l, c, h, a =
			line:find("oklch%s*%(%s*([%d%.]+)%%?%s+([%d%.]+)%s+([%d%.]+)deg?%s*/?%s*([%d%.]*)")
		-- line:find("oklch%s*%(([%d%.]+)%%?%s+([%d%.]+)%s+([%d%.]+)%s*/?%s*([%d%.]*)", offset + 1)

		if not start_idx then
			break
		end

		l = tonumber(l)
		c = tonumber(c)
		h = tonumber(h)
		a = a ~= "" and tonumber(a) or 1

		if l and c and h then
			-- Convert L from percentage if needed (0-100% to 0-1)
			if l > 1 then
				l = l / 100
			end

			-- Convert OKLCH to RGB
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

-- Parse named CSS colors
function M.parse_named_colors(line)
	local results = {}

	for name, hex in pairs(colors.NAMED_COLORS) do
		-- Word boundary pattern to match only complete color names
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
