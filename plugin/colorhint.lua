if vim.fn.has("nvim-0.7.0") ~= 1 then
	vim.api.nvim_err_writeln("colorhint.nvim requires Neovim >= 0.7.0")
	return
end

-- Prevent loading twice
if vim.g.loaded_colorhint then
	return
end
vim.g.loaded_colorhint = 1

-- Check for termguicolors
if not vim.o.termguicolors then
	vim.api.nvim_echo({
		{ "[colorhint.nvim] ", "WarningMsg" },
		{ "termguicolors is not enabled. Colors may not display correctly.", "Normal" },
	}, true, {})
end
