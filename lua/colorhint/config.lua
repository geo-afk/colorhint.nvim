local M = {}

M.options = {
	enabled = true,
	render = "virtual", -- "background", "foreground", "virtual", "both", "underline"

	-- NEW: Allow background for Tailwind classes
	tailwind_render_background = true, -- Set to false if you want only virtual symbols for Tailwind

	-- Virtual text symbol options
	virtual_symbol = "⬤ ",
	virtual_symbol_suffix = " ",
	virtual_symbol_prefix = " ",
	virtual_symbol_position = "before", -- "before" | "after" | "both"

	-- Format toggles
	enable_hex = true,
	enable_short_hex = true,
	enable_rgb = true,
	enable_rgba = true,
	enable_hsl = true,
	enable_hsla = true,
	enable_oklch = true,
	enable_named_colors = false, -- Globally disabled to avoid ambiguity; enable per-filetype below
	enable_tailwind = true,

	-- Context awareness
	context_aware = true,
	use_treesitter = false, -- Experimental; if enabled, could improve key/value distinction but requires nvim-treesitter

	-- File type configuration
	enabled_filetypes = {
		"html",
		"css",
		"scss",
		"sass",
		"less",
		"javascript",
		"typescript",
		"javascriptreact",
		"typescriptreact",
		"vue",
		"svelte",
		"astro",
		"lua",
		"python",
		"go",
		"rust",
	},
	exclude_filetypes = {},
	filetype_overrides = {
		-- Disable named in data formats where colors are keys/values
		json = { enable_named_colors = false },
		yaml = { enable_named_colors = false },
		toml = { enable_named_colors = false },
		lua = { enable_named_colors = false }, -- NEW: Disable for Lua to avoid highlighting keys like "black"
		python = { enable_named_colors = false }, -- NEW: Similar for Python
		javascript = { enable_named_colors = false, context_aware = true },
		typescript = { enable_named_colors = false, context_aware = true },
		javascriptreact = { enable_named_colors = false, context_aware = true },
		typescriptreact = { enable_named_colors = false, context_aware = true },

		-- Enable named only in styling contexts (CSS and similar)
		html = { enable_named_colors = false, context_aware = true }, -- NEW: Disabled unless you want inline style named colors
		css = { enable_named_colors = true, context_aware = true },
		scss = { enable_named_colors = true, context_aware = true },
		sass = { enable_named_colors = true, context_aware = true },
		less = { enable_named_colors = true, context_aware = true },
	},

	-- Tailwind context (only match in class-like attributes)
	tailwind_context = true,
	exclude_buftypes = { "terminal", "prompt", "nofile" },

	-- Performance
	update_delay = 150, -- milliseconds
	max_file_size = 100000, -- bytes, disable for files larger than this

	-- Priorities for overlap resolution (higher = takes precedence)
	format_priority = {
		tailwind = 5,
		rgb = 4,
		rgba = 4,
		hsl = 4,
		hsla = 4,
		oklch = 4,
		hex = 3,
		named = 1,
	},

	-- Extmark priorities (for layering)
	extmark_priority = {
		background = 100,
		foreground = 101,
		virtual = 102,
	},

	-- Notifications
	enable_notifications = true,
}

-- Rest of the file remains the same...
