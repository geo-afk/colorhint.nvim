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
	enable_named_colors = false,
	enable_tailwind = true,

	-- File type configuration
	-- filetypes = { "*" },
	-- exclude_filetypes = {},
	filetype_overrides = {
		-- Disable named in data formats where colors are keys/values
		json = { enable_named_colors = false },
		yaml = { enable_named_colors = false },
		toml = { enable_named_colors = false },
		-- Enable only in styling contexts
		html = { enable_named_colors = true },
		css = { enable_named_colors = true },
		scss = { enable_named_colors = true },
		javascript = { enable_named_colors = true },
		-- Add more as needed
	},
	-- New: Context for Tailwind (e.g., only in class-like strings)
	tailwind_context = true, -- Use improved patterns for attributes/classes
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
