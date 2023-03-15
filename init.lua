local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- set TermGuiColors before loading nvim colorizer
vim.o.termguicolors = true

require("lazy").setup('plugins')

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

-- Set colorscheme
vim.cmd([[colorscheme bluloco-dark]])

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- CmdHeight
vim.o.cmdheight = 0

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

-- Quit neovim
vim.keymap.set("n", "<leader>qq", ":qa<CR>")

-- Select all
vim.keymap.set("n", "<C-a>", "gg<S-v>G")

-- Buffer New
vim.keymap.set("n", "<leader>bn", ":enew<CR>", { desc = "[B]uffer [N]ew" })

-- Move window focus
vim.keymap.set("", "<C-h>", "<C-w>h")
vim.keymap.set("", "<C-k>", "<C-w>k")
vim.keymap.set("", "<C-j>", "<C-w>j")
vim.keymap.set("", "<C-l>", "<C-w>l")

-- Resize window
vim.keymap.set("n", "<C-w><left>", "<C-w><")
vim.keymap.set("n", "<C-w><right>", "<C-w>>")
vim.keymap.set("n", "<C-w><up>", "<C-w>+")
vim.keymap.set("n", "<C-w><down>", "<C-w>-")

-- Tabs
vim.keymap.set("n", "<leader>td", ":tabNext<CR>")
vim.keymap.set("n", "<leader>ta", ":tabprevious<CR>")
vim.keymap.set("n", "<leader>tc", ":tabclose<CR>")
vim.keymap.set("n", "<leader>tn", ":tabnew<CR>")
vim.keymap.set("n", "<leader>tt", ":tabs<CR>")

-- Git Blame
vim.keymap.set("n", "<leader>b", "<Cmd>Gitsigns toggle_current_line_blame<CR>")

-- Git Blame
vim.keymap.set("n", "<leader>zz", "<Cmd>ZenMode<CR>")


-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = "*",
})


-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
require("telescope").setup({
  defaults = {
    mappings = {
      i = {
        ["<C-u>"] = false,
        ["<C-d>"] = false,
      },
    },
  },
  extensions = {
    file_browser = {
      theme = "dropdown",
      hijack_netrw = true,
      previewer = false,
    },
  },
})

-- Telescope Plugins
pcall(require("telescope").load_extension, "fzf")
pcall(require("telescope").load_extension, "file_browser")
pcall(require("telescope").load_extension, "flutter")

-- See `:help telescope.builtin`
vim.keymap.set("n", "<leader>?", require("telescope.builtin").oldfiles, { desc = "[?] Find recently opened files" })
vim.keymap.set("n", "<leader><space>", require("telescope.builtin").buffers, { desc = "[ ] Find existing buffers" })
vim.keymap.set("n", "<leader>f/", function()
  -- You can pass additional configuration to telescope to change theme, layout, etc.
  require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
    winblend = 10,
    previewer = false,
  }))
end, { desc = "[/] Fuzzily search in current buffer]" })

vim.keymap.set("n", "<leader>ff", require("telescope.builtin").find_files, { desc = "[F]ind [F]iles" })
vim.keymap.set("n", "<leader>fh", require("telescope.builtin").help_tags, { desc = "[F]ind [H]elp" })
vim.keymap.set("n", "<leader>fw", require("telescope.builtin").grep_string, { desc = "[F]ind current [W]ord" })
vim.keymap.set("n", "<leader>fg", require("telescope.builtin").live_grep, { desc = "[F]ind by [G]rep" })
vim.keymap.set("n", "<leader>fd", require("telescope.builtin").diagnostics, { desc = "[F]ind [D]iagnostics" })
vim.keymap.set("n", "<leader>fc", require("telescope.builtin").commands, { desc = "[F]ind [C]ommands" })
vim.keymap.set(
  "n",
  "<leader>fb",
  ":Telescope file_browser path=%:p:h select_buffer=true<CR>",
  { desc = "[F]ile [B]rowser", noremap = true }
)
vim.keymap.set("n", "<leader>ft", "<Cmd>TodoTelescope<CR>", { desc = "[F]ind [T]odo" })

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)

-- LSP settings.
--  This function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
  -- NOTE: Remember that lua is a real programming language, and as such it is possible
  -- to define small helper and utility functions so you don't have to repeat yourself
  -- many times.
  --
  -- In this case, we create a function that lets us more easily define mappings specific
  -- for LSP related items. It sets the mode, buffer and description for us each time.
  local nmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end

    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
  end

  -- nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
  -- nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")

  -- nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
  nmap("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
  nmap("gI", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
  nmap("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
  nmap("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
  nmap("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

  -- See `:help K` for why this keymap
  nmap("K", vim.lsp.buf.hover, "Hover Documentation")
  nmap("<C-k>", vim.lsp.buf.signature_help, "Signature Documentation")

  -- Lesser used LSP functionality
  -- nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
  nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
  nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
  nmap("<leader>wl", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, "[W]orkspace [L]ist Folders")

  -- Format command
  nmap("<A-F>", ":Format<CR>", "Formatting file")

  -- Create a command `:Format` local to the LSP buffer
  vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
    vim.lsp.buf.format()
  end, { desc = "Format current buffer with LSP" })

  vim.api.nvim_create_autocmd("BufWritePre", {
    buffer = bufnr,
    command = "Format",
  })
end

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
local servers = {
  -- clangd = {},
  gopls = {},
  -- pyright = {},
  -- rust_analyzer = {},
  tsserver = {},
}

-- Setup neovim lua configuration
require("neodev").setup()
--
-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

-- Setup mason so it can manage external tooling
require("mason").setup()

-- Ensure the servers above are installed
local mason_lspconfig = require("mason-lspconfig")

mason_lspconfig.setup({
  ensure_installed = vim.tbl_keys(servers),
})

mason_lspconfig.setup_handlers({
  function(server_name)
    require("lspconfig")[server_name].setup({
      capabilities = capabilities,
      on_attach = on_attach,
      settings = servers[server_name],
    })
  end,
})

-- Turn on lsp status information
require("fidget").setup()

-- nvim-cmp setup
local cmp = require("cmp")
local luasnip = require("luasnip")

-- LuaSnip
require("luasnip.loaders.from_vscode").lazy_load()
luasnip.filetype_extend("javascript", { "javascriptreact" })
luasnip.filetype_extend("javascript", { "html" })

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  formatting = {
    format = require('lspkind').cmp_format({
      mode = 'symbol_text',
      ellipsis_char = '...',
      maxwidth = 50,
    }),
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "path" },
    -- { name = "buffer" },
  },
})

-- null-ls is used for formatters/diagnostics not provided by the language server
local null_ls = require("null-ls")
null_ls.setup({
  sources = {
    null_ls.builtins.formatting.prettierd,
    -- null_ls.builtins.code_actions.eslint,
    -- null_ls.builtins.diagnostics.eslint,
    -- null_ls.builtins.diagnostics.tsc,
    -- null_ls.builtins.formatting.stylelint,
    -- null_ls.builtins.diagnostics.stylelint,
    -- null_ls.builtins.formatting.json_tool,
    -- null_ls.builtins.diagnostics.jsonlint,
    -- null_ls.builtins.formatting.stylua,
    null_ls.builtins.formatting.gofmt,
    null_ls.builtins.formatting.goimports,
    null_ls.builtins.formatting.goimports_reviser,
    null_ls.builtins.formatting.golines,
    -- null_ls.builtins.diagnostics.golangci_lint,
    -- null_ls.builtins.completion.tags,
  },
})

-- Flutter
require("flutter-tools").setup({
  lsp = {
    capabilities = capabilities,
    on_attach = on_attach,
  }
})

-- Disable TS Formatting
require("lspconfig").tsserver.setup({
  capabilities = capabilities,
  on_attach = function(client)
    client.server_capabilities.documentFormattingProvider = false
  end,
})

-- Eslint Fix All
vim.keymap.set("n", "<leader>efa", "<Cmd>EslintFixAll<CR>")

-- BarBar
require("bufferline").setup({
  diagnostics = {
    [vim.diagnostic.severity.ERROR] = { enabled = true, icon = '' },
    [vim.diagnostic.severity.WARN] = { enabled = false, icon = 'ﬀ' },
    [vim.diagnostic.severity.INFO] = { enabled = false },
    [vim.diagnostic.severity.HINT] = { enabled = true },
  },
})
local baseKeymapsOpts = { noremap = true, silent = true }

-- Move to previous/next
vim.keymap.set("n", "<A-,>", "<Cmd>BufferPrevious<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-.>", "<Cmd>BufferNext<CR>", baseKeymapsOpts)

-- Re-order to previous/next
vim.keymap.set("n", "<C-,>", "<Cmd>BufferMovePrevious<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<C-.>", "<Cmd>BufferMoveNext<CR>", baseKeymapsOpts)

-- Goto buffer in position...
vim.keymap.set("n", "<A-1>", "<Cmd>BufferGoto 1<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-2>", "<Cmd>BufferGoto 2<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-3>", "<Cmd>BufferGoto 3<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-4>", "<Cmd>BufferGoto 4<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-5>", "<Cmd>BufferGoto 5<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-6>", "<Cmd>BufferGoto 6<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-7>", "<Cmd>BufferGoto 7<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-8>", "<Cmd>BufferGoto 8<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-9>", "<Cmd>BufferGoto 9<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<A-0>", "<Cmd>BufferLast<CR>", baseKeymapsOpts)

-- Pin/unpin buffer
vim.keymap.set("n", "<A-p>", "<Cmd>BufferPin<CR>", baseKeymapsOpts)

-- Close buffer
vim.keymap.set("n", "<A-w>", "<Cmd>BufferClose<CR>", baseKeymapsOpts)
-- Wipeout buffer
-- :BufferWipeout
-- Close commands
-- :BufferCloseAllButCurrent
-- :BufferCloseAllButPinned
-- :BufferCloseAllButCurrentOrPinned
-- :BufferCloseBuffersLeft
-- :BufferCloseBuffersRight

-- Magic buffer-picking mode
vim.keymap.set("n", "<C-p>", "<Cmd>BufferPick<CR>", baseKeymapsOpts)

-- Sort automatically by...
vim.keymap.set("n", "<Space>bb", "<Cmd>BufferOrderByBufferNumber<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<Space>bd", "<Cmd>BufferOrderByDirectory<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<Space>bl", "<Cmd>BufferOrderByLanguage<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<Space>bw", "<Cmd>BufferOrderByWindowNumber<CR>", baseKeymapsOpts)

-- Diffview
vim.keymap.set("n", "<leader>dd", "<Cmd>DiffviewOpen<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<leader>dr", "<Cmd>DiffviewRefresh<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<leader>dhf", "<Cmd>DiffviewFileHistory %<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<leader>dh", "<Cmd>DiffviewFileHistory<CR>", baseKeymapsOpts)
vim.keymap.set("n", "<leader>dc", "<Cmd>DiffviewClose<CR>", baseKeymapsOpts)

require("toggleterm").setup({
  size = 15,
  open_mapping = [[<A-t>]],
  direction = "float",
  close_on_exit = true,
  hide_numbers = true,
  shade_filetypes = {},
  shade_terminals = true,
  shading_factor = 5,
  start_in_insert = true,
  insert_mappings = true,
  persist_size = true,
  shell = vim.o.shell,
  float_opts = {
    border = "curved",
    winblend = 0,
    highlights = {
      border = "Normal",
      background = "Normal",
    }
  }
})

function _G.set_terminal_keymaps()
  local opts = { buffer = 0 }
  vim.keymap.set('t', '<C-esc>', [[<C-\><C-n>]], opts)
  -- vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
  vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], opts)
  vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], opts)
  vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], opts)
  vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], opts)
  vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
end

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

local Terminal = require("toggleterm.terminal").Terminal
local lazygit  = Terminal:new({
  cmd = "lazygit",
  hidden = true,
  direction = "float",
  close_on_exit = true,
  hide_numbers = true,
  shade_filetypes = {},
  shade_terminals = true,
  shading_factor = 5,
  start_in_insert = true,
  insert_mappings = true,
  persist_size = true,
  shell = vim.o.shell,
  float_opts = {
    border = "curved",
    winblend = 0,
    highlights = {
      border = "Normal",
      background = "Normal",
    }
  }
})
local top      = Terminal:new({
  cmd = "gotop",
  hidden = true,
  direction = "float",
  close_on_exit = true,
  start_in_insert = true,
})
local node     = Terminal:new({
  cmd = "node",
  hidden = true,
  direction = "float",
  close_on_exit = true,
  start_in_insert = true,
})

function _LAZYGIT_TOGGLE()
  lazygit:toggle()
end

function _TOP_TOGGLE()
  top:toggle()
end

function _NODE_INTERACTIVE_TOGGLE()
  node:toggle()
end

vim.keymap.set("n", "<C-t>g", "<CMD>lua _LAZYGIT_TOGGLE()<CR>", { desc = "Toggle LazyGit" })
vim.keymap.set("n", "<C-t>t", "<CMD>lua _TOP_TOGGLE()<CR>", { desc = "Toggle htop" })
vim.keymap.set("n", "<C-t>n", "<CMD>lua _NODE_INTERACTIVE_TOGGLE()<CR>", { desc = "Toggle Node Interactive" })
