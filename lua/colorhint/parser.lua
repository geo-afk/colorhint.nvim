local M = {}
local config = require("colorhint.config")
local colors = require("colorhint.colors")
local tailwind = require("colorhint.color.tailwind")

function M.parse_line(line)
	local all_colors = {}

	-- Always parse Tailwind first if enabled (claims full classes)
	if config.options.enable_tailwind then
		vim.list_extend(all_colors, tailwind.parse_tailwind(line))
	end

	if config.options.enable_hex then
		vim.list_extend(all_colors, M.parse_hex(line))
	end

	-- ... other parsers (RGB, HSL, etc.) ...

	-- Named colors LAST, and only if not disabled
	local ft = vim.bo.filetype
	local overrides = config.options.filetype_overrides[ft] or {}
	local enable_named = config.options.enable_named_colors
	if overrides.enable_named_colors ~= nil then
		enable_named = overrides.enable_named_colors
	elseif config.options.disable_named_on_tailwind and config.options.enable_tailwind then
		enable_named = false -- Skip entirely if Tailwind is on
	end
	if enable_named then
		vim.list_extend(all_colors, M.parse_named_colors(line))
	end

	-- Dedupe and sort by start position
	table.sort(all_colors, function(a, b)
		return a.start < b.start
	end)
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

return M
