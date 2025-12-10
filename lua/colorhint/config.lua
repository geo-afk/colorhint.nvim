local M = {}

M.options = {
	enabled = true,
	render = "virtual", -- "background", "foreground", "virtual", "both", "underline"

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
	enable_named_colors = false, -- Disabled by default due to ambiguity
	enable_tailwind = true,

	-- Context awareness (NEW)
	context_aware = true, -- Only highlight colors in appropriate contexts
	use_treesitter = false, -- Use treesitter for context detection (more accurate, experimental)

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
		-- Enable only in styling contexts
		html = { enable_named_colors = true, context_aware = true },
		css = { enable_named_colors = true, context_aware = true },
		scss = { enable_named_colors = true, context_aware = true },
		javascript = { enable_named_colors = false, context_aware = true },
		typescript = { enable_named_colors = false, context_aware = true },
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

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})

	-- Apply filetype overrides if present
	local ft = vim.bo.filetype
	if M.options.filetype_overrides[ft] then
		local overrides = M.options.filetype_overrides[ft]
		M.options = vim.tbl_extend("force", M.options, overrides)
	end
end

-- Get effective config for current buffer
function M.get_buffer_config()
	local ft = vim.bo.filetype
	local base = vim.deepcopy(M.options)

	if M.options.filetype_overrides[ft] then
		return vim.tbl_extend("force", base, M.options.filetype_overrides[ft])
	end

	return base
end

return M
