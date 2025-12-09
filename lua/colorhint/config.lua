local M = {}

M.options = {
	enabled = true,
	render = "both",
	virtual_symbol = "■",
	virtual_symbol_suffix = " ",

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
