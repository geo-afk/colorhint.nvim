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

return M
