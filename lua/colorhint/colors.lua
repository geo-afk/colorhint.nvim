local M = {}

-- Named CSS colors database
M.NAMED_COLORS = {
	aliceblue = "#f0f8ff",
	antiquewhite = "#faebd7",
	aqua = "#00ffff",
	aquamarine = "#7fffd4",
	azure = "#f0ffff",
	beige = "#f5f5dc",
	bisque = "#ffe4c4",
	black = "#000000",
	blanchedalmond = "#ffebcd",
	blue = "#0000ff",
	blueviolet = "#8a2be2",
	brown = "#a52a2a",
	burlywood = "#deb887",
	cadetblue = "#5f9ea0",
	chartreuse = "#7fff00",
	chocolate = "#d2691e",
	coral = "#ff7f50",
	cornflowerblue = "#6495ed",
	cornsilk = "#fff8dc",
	crimson = "#dc143c",
	cyan = "#00ffff",
	darkblue = "#00008b",
	darkcyan = "#008b8b",
	darkgoldenrod = "#b8860b",
	darkgray = "#a9a9a9",
	darkgreen = "#006400",
	darkgrey = "#a9a9a9",
	darkkhaki = "#bdb76b",
	darkmagenta = "#8b008b",
	darkolivegreen = "#556b2f",
	darkorange = "#ff8c00",
	darkorchid = "#9932cc",
	darkred = "#8b0000",
	darksalmon = "#e9967a",
	darkseagreen = "#8fbc8f",
	darkslateblue = "#483d8b",
	darkslategray = "#2f4f4f",
	darkslategrey = "#2f4f4f",
	darkturquoise = "#00ced1",
	darkviolet = "#9400d3",
	deeppink = "#ff1493",
	deepskyblue = "#00bfff",
	dimgray = "#696969",
	dimgrey = "#696969",
	dodgerblue = "#1e90ff",
	firebrick = "#b22222",
	floralwhite = "#fffaf0",
	forestgreen = "#228b22",
	fuchsia = "#ff00ff",
	gainsboro = "#dcdcdc",
	ghostwhite = "#f8f8ff",
	gold = "#ffd700",
	goldenrod = "#daa520",
	gray = "#808080",
	green = "#008000",
	greenyellow = "#adff2f",
	grey = "#808080",
	honeydew = "#f0fff0",
	hotpink = "#ff69b4",
	indianred = "#cd5c5c",
	indigo = "#4b0082",
	ivory = "#fffff0",
	khaki = "#f0e68c",
	lavender = "#e6e6fa",
	lavenderblush = "#fff0f5",
	lawngreen = "#7cfc00",
	lemonchiffon = "#fffacd",
	lightblue = "#add8e6",
	lightcoral = "#f08080",
	lightcyan = "#e0ffff",
	lightgoldenrodyellow = "#fafad2",
	lightgray = "#d3d3d3",
	lightgreen = "#90ee90",
	lightgrey = "#d3d3d3",
	lightpink = "#ffb6c1",
	lightsalmon = "#ffa07a",
	lightseagreen = "#20b2aa",
	lightskyblue = "#87cefa",
	lightslategray = "#778899",
	lightslategrey = "#778899",
	lightsteelblue = "#b0c4de",
	lightyellow = "#ffffe0",
	lime = "#00ff00",
	limegreen = "#32cd32",
	linen = "#faf0e6",
	magenta = "#ff00ff",
	maroon = "#800000",
	mediumaquamarine = "#66cdaa",
	mediumblue = "#0000cd",
	mediumorchid = "#ba55d3",
	mediumpurple = "#9370db",
	mediumseagreen = "#3cb371",
	mediumslateblue = "#7b68ee",
	mediumspringgreen = "#00fa9a",
	mediumturquoise = "#48d1cc",
	mediumvioletred = "#c71585",
	midnightblue = "#191970",
	mintcream = "#f5fffa",
	mistyrose = "#ffe4e1",
	moccasin = "#ffe4b5",
	navajowhite = "#ffdead",
	navy = "#000080",
	oldlace = "#fdf5e6",
	olive = "#808000",
	olivedrab = "#6b8e23",
	orange = "#ffa500",
	orangered = "#ff4500",
	orchid = "#da70d6",
	palegoldenrod = "#eee8aa",
	palegreen = "#98fb98",
	paleturquoise = "#afeeee",
	palevioletred = "#db7093",
	papayawhip = "#ffefd5",
	peachpuff = "#ffdab9",
	peru = "#cd853f",
	pink = "#ffc0cb",
	plum = "#dda0dd",
	powderblue = "#b0e0e6",
	purple = "#800080",
	rebeccapurple = "#663399",
	red = "#ff0000",
	rosybrown = "#bc8f8f",
	royalblue = "#4169e1",
	saddlebrown = "#8b4513",
	salmon = "#fa8072",
	sandybrown = "#f4a460",
	seagreen = "#2e8b57",
	seashell = "#fff5ee",
	sienna = "#a0522d",
	silver = "#c0c0c0",
	skyblue = "#87ceeb",
	slateblue = "#6a5acd",
	slategray = "#708090",
	slategrey = "#708090",
	snow = "#fffafa",
	springgreen = "#00ff7f",
	steelblue = "#4682b4",
	tan = "#d2b48c",
	teal = "#008080",
	thistle = "#d8bfd8",
	tomato = "#ff6347",
	turquoise = "#40e0d0",
	violet = "#ee82ee",
	wheat = "#f5deb3",
	white = "#ffffff",
	whitesmoke = "#f5f5f5",
	yellow = "#ffff00",
	yellowgreen = "#9acd32",
}

-- Convert hex to RGB
function M.hex_to_rgb(hex)
	hex = hex:gsub("#", "")

	-- Expand short hex
	if #hex == 3 then
		hex = hex:gsub("(%x)", "%1%1")
	end

	local r = tonumber(hex:sub(1, 2), 16) or 0
	local g = tonumber(hex:sub(3, 4), 16) or 0
	local b = tonumber(hex:sub(5, 6), 16) or 0
	local a = #hex == 8 and (tonumber(hex:sub(7, 8), 16) or 255) or 255

	return r, g, b, a
end

-- Convert RGB to hex
function M.rgb_to_hex(r, g, b, a)
	-- Clamp values
	r = math.max(0, math.min(255, math.floor(r + 0.5)))
	g = math.max(0, math.min(255, math.floor(g + 0.5)))
	b = math.max(0, math.min(255, math.floor(b + 0.5)))

	if a and a < 1 then
		a = math.max(0, math.min(255, math.floor(a * 255 + 0.5)))
		return string.format("#%02x%02x%02x%02x", r, g, b, a)
	end

	return string.format("#%02x%02x%02x", r, g, b)
end

-- Convert HSL to RGB
function M.hsl_to_rgb(h, s, l)
	h = h / 360
	s = s / 100
	l = l / 100

	local function hue_to_rgb(p, q, t)
		if t < 0 then
			t = t + 1
		end
		if t > 1 then
			t = t - 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		end
		if t < 1 / 2 then
			return q
		end
		if t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end

	local r, g, b
	if s == 0 then
		r, g, b = l, l, l
	else
		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q
		r = hue_to_rgb(p, q, h + 1 / 3)
		g = hue_to_rgb(p, q, h)
		b = hue_to_rgb(p, q, h - 1 / 3)
	end

	return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end

-- Convert OKLCH to RGB (via OKLab and XYZ)
function M.oklch_to_rgb(l, c, h)
	-- Convert OKLCH to OKLab
	local h_rad = math.rad(h)
	local a = c * math.cos(h_rad)
	local b = c * math.sin(h_rad)

	-- OKLab to linear RGB (D65 illuminant)
	local l_ = l + 0.3963377774 * a + 0.2158037573 * b
	local m_ = l - 0.1055613458 * a - 0.0638541728 * b
	local s_ = l - 0.0894841775 * a - 1.2914855480 * b

	local l_cubed = l_ * l_ * l_
	local m_cubed = m_ * m_ * m_
	local s_cubed = s_ * s_ * s_

	local r_linear = 4.0767416621 * l_cubed - 3.3077115913 * m_cubed + 0.2309699292 * s_cubed
	local g_linear = -1.2684380046 * l_cubed + 2.6097574011 * m_cubed - 0.3413193965 * s_cubed
	local b_linear = -0.0041960863 * l_cubed - 0.7034186147 * m_cubed + 1.7076147010 * s_cubed

	-- Apply gamma correction (sRGB)
	local function gamma_correct(c)
		if c <= 0.0031308 then
			return 12.92 * c
		else
			return 1.055 * math.pow(c, 1 / 2.4) - 0.055
		end
	end

	local r = gamma_correct(r_linear)
	local g = gamma_correct(g_linear)
	local b = gamma_correct(b_linear)

	-- Clamp and convert to 0-255
	r = math.max(0, math.min(1, r)) * 255
	g = math.max(0, math.min(1, g)) * 255
	b = math.max(0, math.min(1, b)) * 255

	return math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5)
end

-- Calculate perceived brightness (for contrast)
function M.get_perceived_brightness(r, g, b)
	-- Use relative luminance formula (Rec. 709)
	return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
end

-- Determine if dark text should be used
function M.should_use_dark_text(r, g, b)
	return M.get_perceived_brightness(r, g, b) > 0.5
end


-- Tailwind CSS v3+ default color palette (most common)
M.TAILWIND_COLORS = {
	slate = { 50="#f8fafc", 100="#f1f5f9", 200="#e2e8f0", 300="#cbd5e1", 400="#94a3b8", 500="#64748b", 600="#475569", 700="#334155", 800="#1e293b", 900="#0f172a" },
	gray = { 50="#f9fafb", 100="#f3f4f6", 200="#e5e7eb", 300="#d1d5db", 400="#9ca3af", 500="#6b7280", 600="#4b5563", 700="#374151", 800="#1f2937", 900="#111827" },
	zinc = { 50="#fafafa", 100="#f4f4f5", 200="#e4e4e7", 300="#d4d4d8", 400="#a1a1aa", 500="#71717a", 600="#525252", 700="#3f3f46", 800="#27272a", 900="#18181b" },
	neutral = { 50="#fafafa", 100="#f5f5f5", 200="#e5e5e5", 300="#d4d4d4", 400="#a3a3a3", 500="#737373", 600="#525252", 700="#404040", 800="#262626", 900="#171717" },
	stone = { 50="#fafaf9", 100="#f5f5f4", 200="#e7e5e4", 300="#d6d3d1", 400="#a8a29e", 500="#78716c", 600="#57534e", 700="#44403c", 800="#292524", 900="#1c1917" },
	red = { 50="#fef2f2", 100="#fee2e2", 200="#fecaca", 300="#fca5a5", 400="#f87171", 500="#ef4444", 600="#dc2626", 700="#b91c1c", 800="#991b1b", 900="#7f1a1a" },
	orange = { 50="#fff7ed", 100="#ffedd5", 200="#fed7aa", 300="#fb923c", 400="#fb923c", 500="#f97316", 600="#ea580c", 700="#c2410c", 800="#9f1239", 900="#7c2d12" },
	amber = { 50="#fffbeb", 100="#fef3c7", 200="#fde68a", 300="#fcd34d", 400="#fbbf24", 500="#f59e0b", 600="#d97706", 700="#b45309", 800="#92400e", 900="#78350f" },
	yellow = { 50="#fefce8", 100="#fef9c3", 200="#fef08a", 300="#fde047", 400="#facc15", 500="#eab308", 600="#ca8a04", 700="#a16207", 800="#854d0e", 900="#713f12" },
	lime = { 50="#f7fee7", 100="#ecfccb", 200="#d9f99d", 300="#bef264", 400="#a3e635", 500="#84cc16", 600="#65a30d", 700="#4d7c0f", 800="#3f6212", 900="#365314" },
	green = { 50="#f0fdf4", 100="#dcfce7", 200="#bbf7d0", 300="#86efac", 400="#4ade80", 500="#22c55e", 600="#16a34a", 700="#15803d", 800="#166534", 900="#14532d" },
	emerald = { 50="#ecfdf5", 100="#d1fae5", 200="#a7f3d0", 300="#6ee7b7", 400="#34d399", 500="#10b981", 600="#059669", 700="#047857", 800="#065f46", 900="#064e3b" },
	teal = { 50="#f0fdfa", 100="#ccfbf1", 200="#99f6e4", 300="#5eead4", 400="#2dd4bf", 500="#14b8a6", 600="#0d9488", 700="#0f766e", 800="#115e59", 900="#134e4a" },
	cyan = { 50="#ecfdff", 100="#cffafe", 200="#a5f3fc", 300="#67e8f9", 400="#22d3ee", 500="#06cddb", 600="#0891b2", 700="#0e7490", 800="#155e75", 900="#164e63" },
	sky = { 50="#f0f9ff", 100="#e0f2fe", 200="#bae6fd", 300="#7dd3fc", 400="#38bdf8", 500="#0ea5e9", 600="#0284c7", 700="#0369a1", 800="#075985", 900="#0c4a6e" },
	blue = { 50="#eff6ff", 100="#dbeafe", 200="#bfdbfe", 300="#93c5fd", 400="#60a5fa", 500="#3b82f6", 600="#2563eb", 700="#1d4ed8", 800="#1e40af", 900="#1e3a8a" },
	indigo = { 50="#eef2ff", 100="#e0e7ff", 200="#c7d2fe", 300="#a5b4fc", 400="#818cf8", 500="#6366f1", 600="#4f46e5", 700="#4338ca", 800="#3730a3", 900="#312e81" },
	violet = { 50="#f5f3ff", 100="#ede9fe", 200="#ddd6fe", 300="#c4b5fd", 400="#a78bfa", 500="#8b5cf6", 600="#7c3aed", 700="#6d28d9", 800="#5b21b6", 900="#4c1d95" },
	purple = { 50="#faf5ff", 100="#f3e8ff", 200="#e9d5ff", 300="#d8b4fe", 400="#c084fc", 500="#a855f7", 600="#9333ea", 700="#7e22ce", 800="#6b21a8", 900="#581c87" },
	fuchsia = { 50="#fdf4ff", 100="#fae8ff", 200="#f5d0fe", 300="#f0abfc", 400="#e879f9", 500="#d946ef", 600="#c11574", 700="#a21caf", 800="#8601b5", 900="#740190" },
	pink = { 50="#fdf2f8", 100="#fce7f3", 200="#fbcfe8", 300="#f9a8d4", 400="#f472b6", 500="#ec4899", 600="#db2777", 700="#be185d", 800="#9d174d", 900="#831843" },
	rose = { 50="#fff1f2", 100="#ffe4e6", 200="#fecdd3", 300="#fda4af", 400="#fb7185", 500="#f43f5e", 600="#e11d48", 700="#be123c", 800="#9f1239", 900="#881337" },
	white = "#ffffff",
	black = "#000000",
	current = "currentColor",
	transparent = "#00000000",
}

-- Convert Tailwind color name + shade to hex
function M.tailwind_color_to_hex(name, shade)
	name = name:lower()
	shade = tostring(shade)

	if name == "white" then return "#ffffff" end
	if name == "black" then return "#000000" end
	if name == "transparent" then return "#00000000" end

	local palette = M.TAILWIND_COLORS[name]
	if not palette then return nil end

	return palette[shade] or palette["500"]
end

-- Parse rgb()/rgba()/hsl() strings (for arbitrary values)
function M.parse_function_color(str)
	local r, g, b, a

	if str:match("^#[%da-fA-F]+") then
		return M.hex_to_rgb(str)
	end

	r, g, b, a = str:match("rgb%a*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*[,%s/]?%s*([%d%.]*)")
	if r then
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		a = a ~= "" and tonumber(a) or (a and a ~= "0" and 1 or nil)
		return r, g, b, a
	end

	-- Add HSL support later if needed
	return nil
end

return M
