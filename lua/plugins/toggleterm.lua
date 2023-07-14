return {
  "akinsho/toggleterm.nvim",
  lazy = false,
  opts = {
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
  },
  keys = {
    { "<C-t>g", "<CMD>lua _LAZYGIT_TOGGLE()<CR>",          mode = "n", desc = "Toggle LazyGit" },
    { "<C-t>t", "<CMD>lua _TOP_TOGGLE()<CR>",              mode = "n", desc = "Toggle htop" },
    { "<C-t>n", "<CMD>lua _NODE_INTERACTIVE_TOGGLE()<CR>", mode = "n", desc = "Toggle Node Interactive" },
  },
  config = function(_, opts)
    require("toggleterm").setup(opts)

    function _G.set_terminal_keymaps()
      local option = { buffer = 0 }
      vim.keymap.set('t', '<C-esc>', [[<C-\><C-n>]], option)
      -- vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
      vim.keymap.set('t', '<C-h>', [[<Cmd>wincmd h<CR>]], option)
      vim.keymap.set('t', '<C-j>', [[<Cmd>wincmd j<CR>]], option)
      vim.keymap.set('t', '<C-k>', [[<Cmd>wincmd k<CR>]], option)
      vim.keymap.set('t', '<C-l>', [[<Cmd>wincmd l<CR>]], option)
      vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], option)
    end

    -- if you only want these mappings for toggle term use term://*toggleterm#* instead
    vim.cmd('autocmd! TermOpen term://* lua set_terminal_keymaps()')

    local Terminal = require("toggleterm.terminal").Terminal
    local lazygit  = Terminal:new({
      cmd = "lazygit",
      hidden = true,
      direction = "tab",
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

    function _LAZYGIT_TOGGLE()
      lazygit:toggle()
    end

    function _TOP_TOGGLE()
      top:toggle()
    end
  end
}
