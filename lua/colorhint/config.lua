local M = {}

M.options = {
	enabled = true,
	render = "both",
	--  ■, ⬤, or ● — they render more consistently across fonts than ██.
	-- virtual_symbol = "■",
	virtual_symbol = "⬤ ",
	virtual_symbol_suffix = " ", -- space after symbol when placed before
	virtual_symbol_prefix = " ", -- space before symbol when placed after
	virtual_symbol_position = "before", -- new option: "before" | "after" | "both"

	-- Format toggles
	enable_hex = true,
	enable_short_hex = true,
	enable_rgb = true,
	enable_rgba = true,
	enable_hsl = true,
	enable_hsla = true,
	enable_oklch = true,
	enable_named_colors = true,
	enable_tailwind = false,

	-- File type configuration
	filetypes = { "*" },
	exclude_filetypes = {},
	exclude_buftypes = { "terminal", "prompt" },

	-- Performance
	update_delay = 100,

	-- Notifications
	enable_notifications = true,
}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
