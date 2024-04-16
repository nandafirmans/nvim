-- [[ Basic Keymaps ]]

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Save File
vim.keymap.set({ "n", "v", "i" }, "<C-s>", "<Cmd>w!<CR>")

-- Close Buffer
vim.keymap.set("n", "<A-q>", ":q<CR>")

-- Force Close Buffer
vim.keymap.set("n", "<A-q>q", ":q!<CR>")

-- Previous Buffer
vim.keymap.set("n", "<s-tab>", "<Cmd>bprevious<CR>", { desc = "Previous Buffer" })

-- Next Buffer
vim.keymap.set("n", "<tab>", "<Cmd>bnext<CR>", { desc = "Next Buffer" })

-- Close All buffer except current
vim.keymap.set("n", "<A-W>", "<Cmd>%bd|e#|bd#<CR>", { desc = "Close All Buffer Except Current" })

-- Clear Search
vim.keymap.set({ "n", "v", "i" }, "<A-c>", "<Cmd>nohlsearch<CR>", { desc = "Clear Search" })

-- Select all
vim.keymap.set("n", "<C-a>", "gg<S-v>G")

-- Delete without yanking
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d')

-- Paste without yanking in visual mode
vim.keymap.set("v", "p", 'P', { noremap = true, silent = true })

-- Buffer New
vim.keymap.set("n", "<leader>bn", ":enew<CR>", { desc = "[B]uffer [N]ew" })

-- Resize window
vim.keymap.set("n", "<C-w><left>", "<C-w><")
vim.keymap.set("n", "<C-w><right>", "<C-w>>")
vim.keymap.set("n", "<C-w><up>", "<C-w>+")
vim.keymap.set("n", "<C-w><down>", "<C-w>-")

-- Tabs
vim.keymap.set("n", "<A-}>", ":tabNext<CR>")
vim.keymap.set("n", "<A-{>", ":tabprevious<CR>")
vim.keymap.set("n", "<A-T>w", ":tabclose<CR>")
vim.keymap.set("n", "<A-T>n", ":tabnew<CR>")
vim.keymap.set("n", "<A-T>l", ":tabs<CR>", { desc = "Tab List" })

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)
