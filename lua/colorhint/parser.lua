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

	if config.options.enable_tailwind then
		vim.list_extend(all_colors, M.parse_tailwind(line))
	end

	return all_colors
end

-- Parse hex colors
function M.parse_hex(line)
	local results = {}
	local idx = 1

	while idx <= #line do
		local start_pos, end_pos, hex = line:find("(#%x%x%x%x%x%x%x?%x?)", idx)
		if not start_pos then
			break
		end

		local len = end_pos - start_pos + 1
		if len == 7 or len == 9 then
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

	-- Short hex #rgb (only if enabled)
	if config.options.enable_short_hex then
		idx = 1
		while idx <= #line do
			local start_pos, end_pos, hex = line:find("(#%x%x%x)(%W)", idx)
			if not start_pos then
				break
			end

			-- Avoid matching inside longer hex
			local inside_long = false
			for _, r in ipairs(results) do
				if start_pos >= r.start + 1 and end_pos <= r.finish + 1 then
					inside_long = true
					break
				end
			end

			if not inside_long then
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

-- Parse Tailwind CSS color classes: bg-red-500, text-blue-400/50, etc.
function M.parse_tailwind(line)
	if not config.options.enable_tailwind then
		return {}
	end

	local results = {}
	local patterns = {
		-- Standard: bg-red-500, text-indigo-600, border-emerald-400
		"([%w%-]+)%-([%w%-]+)%-([%d]+)",
		-- With opacity: bg-sky-500/50, text-purple-400/[.2]
		"([%w%-]+)%-([%w%-]+)%-([%d]+)/[%d%.]+",
		-- Arbitrary values: bg-[#ff0000], text-[rgb(255,0,0)]
		"([%w%-]+)%-%[%s*(#[%da-fA-F]+)%s*%]", -- bg-[#rrggbb]
		"([%w%-]+)%-%[%s*rgb%a*%s*%(%s*%d+%s*,%s*%d+%s*,%s*%d+[^%)]*%)%s*%]", -- rgb/rgba
		"([%w%-]+)%-%[%s*hsl%a*%s*%(%s*%d+[^%)]*%)%s*%]", -- hsl/hsla
	}

	-- Tailwind color prefixes that represent visual color (not layout/spacing)
	local color_prefixes = {
		"bg%",
		"text%",
		"border%",
		"ring%",
		"ring%-offset%",
		"shadow%",
		"decoration%",
		"accent%",
		"caret%",
		"from%",
		"via%",
		"to%",
		"fill%",
		"stroke%",
	}

	for _, prefix in ipairs(color_prefixes) do
		prefix = prefix:gsub("%%", "") -- remove % used for pattern escaping

		for _, pattern in ipairs(patterns) do
			local full_pattern = prefix .. "%-" .. pattern
			local init = 1
			while true do
				local s, e, p1, color_name, shade_or_custom = line:find(full_pattern, init)
				if not s then
					break
				end

				local full_match = line:sub(s, e)
				local hex = nil

				-- Resolve Tailwind color name + shade to hex (e.g., red-500)
				if color_name and shade_or_custom and not full_match:find("%[") then
					hex = colors.tailwind_color_to_hex(color_name, shade_or_custom)
				end

				-- Handle arbitrary values inside [...]
				if full_match:find("%[") then
					local arb = full_match:match("%[([^%]]+)%]")
					if arb then
						arb = arb:gsub("%s", "")
						if arb:match("^#") then
							hex = arb:lower()
							if #hex == 4 then
								hex = hex .. hex:sub(2)
							end -- expand #rgb
						elseif arb:match("^rgb") or arb:match("^hsl") then
							-- Extract and parse rgb()/hsl()
							local r, g, b, a = colors.parse_function_color(arb)
							if r then
								hex = colors.rgb_to_hex(r, g, b, a)
							end
						end
					end
				end

				if hex then
					table.insert(results, {
						color = hex,
						start = s - 1,
						finish = e,
						format = "tailwind",
					})
				end

				init = e + 1
			end
		end
	end

	return results
end

return M
