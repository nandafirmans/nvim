local M = {}

function M.setup()
  local numbertoggle = vim.api.nvim_create_augroup("NumberToggle", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "WinEnter" }, {
    group = numbertoggle,
    callback = function()
      if vim.wo.number and vim.api.nvim_get_mode().mode ~= "i" then
        vim.wo.relativenumber = true
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "WinLeave" }, {
    group = numbertoggle,
    callback = function()
      if vim.wo.number then
        vim.wo.relativenumber = false
      end
    end,
  })

  local yank_highlight = vim.api.nvim_create_augroup("YankHighlight", { clear = true })

  vim.api.nvim_create_autocmd("TextYankPost", {
    group = yank_highlight,
    pattern = "*",
    callback = function()
      vim.highlight.on_yank()
    end,
  })

  if vim.g.neovide then
    vim.o.guifont = "MesloLGM Nerd Font Mono:h9"
    vim.keymap.set("n", "<F11>", function()
      vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
    end, { desc = "Toggle Neovide fullscreen" })
  end
end

return M
