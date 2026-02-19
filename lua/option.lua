-- [[ Setting options ]]
vim.o.autoindent = true
vim.o.smartindent = true
vim.o.expandtab = true
vim.o.cursorline = true
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 4
vim.o.encoding = "utf8"
vim.o.history = 5000
vim.o.hidden = true
vim.o.swapfile = false
vim.o.clipboard = "unnamedplus"
vim.o.guifont = "Victor Mono Nerd Font:h10"
-- vim.o.laststatus = 3
vim.o.laststatus = 0
vim.o.statusline = "%{repeat('─',winwidth('.'))}"

-- Neovide
if vim.g.neovide then
	vim.o.guifont = "MesloLGM Nerd Font Mono:h9"
	vim.api.nvim_set_keymap("n", "<F11>", ":let g:neovide_fullscreen = !g:neovide_fullscreen<CR>", {})
end

-- Folding
vim.o.foldmethod = "indent"
vim.o.foldlevelstart = 99

-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set highlight on search
vim.o.hlsearch = true

-- Make line numbers default
vim.wo.number = true

-- Relative Number on normal mode only
vim.cmd([[
  augroup numbertoggle
    autocmd!
    autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
    autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
  augroup END
]])

-- Enable mouse mode
vim.o.mouse = "a"

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
-- vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Decrease update time
vim.o.updatetime = 250
vim.wo.signcolumn = "yes"

vim.cmd("colorschem nightfly")

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- CmdHeight
vim.o.cmdheight = 0

-- NOTE: Highlight on yank
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

-- make background transparent
-- vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
-- vim.cmd("highlight NonText guibg=NONE ctermbg=NONE")

vim.diagnostic.config({
	virtual_text = {
		severity = { min = vim.diagnostic.severity.WARN },
		source = "if_many",
		spacing = 4,
	},
	signs = true,
	update_in_insert = false,
	severity_sort = true,
})
