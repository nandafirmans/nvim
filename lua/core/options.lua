local M = {}

function M.setup()
  local opt = vim.opt

  opt.autoindent = true
  opt.smartindent = true
  opt.expandtab = true
  opt.cursorline = true
  opt.shiftwidth = 2
  opt.tabstop = 4
  opt.encoding = "utf8"
  opt.history = 5000
  opt.hidden = true
  opt.swapfile = false
  opt.clipboard = "unnamedplus"
  opt.guifont = "Victor Mono Nerd Font:h10"

  opt.laststatus = 0
  opt.statusline = "%{repeat('─',winwidth('.'))}"

  opt.foldmethod = "indent"
  opt.foldlevelstart = 99

  opt.hlsearch = true
  opt.number = true
  opt.mouse = "a"
  opt.breakindent = true
  opt.ignorecase = true
  opt.smartcase = true
  opt.updatetime = 250
  opt.signcolumn = "yes"
  opt.completeopt = "menuone,noselect"
  opt.cmdheight = 0
end

return M
