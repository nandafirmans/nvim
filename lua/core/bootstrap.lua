local M = {}

function M.setup()
  vim.g.mapleader = " "
  vim.g.maplocalleader = " "

  vim.o.termguicolors = true

  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1
end

function M.setup_lazy()
  local uv = vim.uv or vim.loop
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

  if not uv.fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      lazypath,
    })
  end

  vim.opt.rtp:prepend(lazypath)
end

return M
