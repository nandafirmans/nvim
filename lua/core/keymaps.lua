local M = {}

function M.setup()
  vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

  vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
  vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

  vim.keymap.set({ "n", "v", "i" }, "<C-s>", "<Cmd>w!<CR>")
  vim.keymap.set({ "n", "v", "i" }, "<A-s>", "<Cmd>wa<CR>")

  vim.keymap.set("n", "<leader>q", ":q<CR>")
  vim.keymap.set("n", "<leader>Q", ":q!<CR>")

  vim.keymap.set("n", "<S-Tab>", "<Cmd>bprevious<CR>", { desc = "Previous Buffer" })
  vim.keymap.set("n", "<Tab>", "<Cmd>bnext<CR>", { desc = "Next Buffer" })
  vim.keymap.set("n", "<A-W>", "<Cmd>%bd|e#|bd#<CR>", { desc = "Close All Buffer Except Current" })

  vim.keymap.set({ "n", "v", "i" }, "<A-c>", "<Cmd>nohlsearch<CR>", { desc = "Clear Search" })
  vim.keymap.set("n", "<C-a>", "gg<S-v>G")

  vim.keymap.set({ "n", "v" }, "<leader>d", '"_d')
  vim.keymap.set("v", "p", "P", { noremap = true, silent = true })
  vim.keymap.set("n", "<leader>bn", ":enew<CR>", { desc = "[B]uffer [N]ew" })

  vim.keymap.set("n", "<C-w>h", "<C-w><")
  vim.keymap.set("n", "<C-w>l", "<C-w>>")
  vim.keymap.set("n", "<C-w>k", "<C-w>+")
  vim.keymap.set("n", "<C-w>j", "<C-w>-")

  vim.keymap.set("n", "<A-}>", ":tabNext<CR>")
  vim.keymap.set("n", "<A-{>", ":tabprevious<CR>")
  vim.keymap.set("n", "<A-T>w", ":tabclose<CR>")
  vim.keymap.set("n", "<A-T>n", ":tabnew<CR>")
  vim.keymap.set("n", "<A-T>l", ":tabs<CR>", { desc = "Tab List" })
end

return M
