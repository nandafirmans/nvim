return {
  {
    'christoomey/vim-tmux-navigator',
    lazy = false,
    keys = {
      { "C-h", "<Cmd>TmuxNavigateLeft<CR>",  mode = "n" },
      { "C-j", "<Cmd>TmuxNavigateDown<CR>",  mode = "n" },
      { "C-k", "<Cmd>TmuxNavigateUp<CR>",    mode = "n" },
      { "C-l", "<Cmd>TmuxNavigateRight<CR>", mode = "n" },
    }
  },

  {
    'ThePrimeagen/harpoon',
    dependencies = { 'nvim-lua/plenary.nvim' },
    lazy = false,
    keys = {
      {
        "<leader>hh",
        function()
          require("harpoon.ui").toggle_quick_menu()
        end,
        mode = "n"
      },
      {
        "<leader>ha",
        function()
          require("harpoon.mark").add_file()
        end,
        mode = "n"
      },
      {
        "<leader>hx",
        function()
          require("harpoon.mark").clear_all()
        end,
        mode = "n"
      },
      {
        "<leader>hj",
        function()
          require("harpoon.ui").nav_next()
        end,
        mode = "n"
      },
      {
        "<leader>hk",
        function()
          require("harpoon.ui").nav_prev()
        end,
        mode = "n"
      }
    },
    config = function()
      require("harpoon").setup({
        menu = {
          width = 120,
        }
      })
    end
  },

  {
    'ojroques/nvim-bufdel',
    lazy = false,
    keys = {
      { "<A-w>", "<Cmd>BufDel<CR>", mode = "n", desc = "Buffer Close" }
    },
    config = function()
      require('bufdel').setup({
        next = 'alternate', -- or 'previous'
        quit = false,       -- exit vim if last buffer deleted
      })
    end
  },

  -- AutoSession & SessionLens
  {
    "rmagatti/auto-session",
    lazy = false,
    keys = {
      {
        "<leader>sd",
        "<Cmd>Autosession delete<CR>",
        mode = "n",
        desc = "[S]ession [D]elete"
      },
      { "<leader>ss", function() require("auto-session.session-lens").search_session() end, mode = "n" }
    },
    config = function()
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"


      local function close_alpha_if_open()
        vim.cmd([[
          if &ft == 'alpha'
            Alpha
          endif
        ]])
      end

      require("auto-session").setup({
        pre_save_cmds = { close_alpha_if_open, "tabdo NvimTreeClose", "tabdo DiffviewClose", },
      })
    end
  },

  -- Auto close tag
  {
    "windwp/nvim-ts-autotag",
    config = function()
      require("nvim-ts-autotag").setup()
    end
  },

  -- Auto pair char
  {
    "windwp/nvim-autopairs",
    config = function()
      require("nvim-autopairs").setup({
        disable_filetype = { "TelescopePrompt", "vim" },
      })
    end
  },

  -- Multi Cursor
  {
    "mg979/vim-visual-multi",
    branch = "master"
  },

  -- Show hex color and rgb
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup()
    end
  },

  -- ZenMode
  {
    "folke/zen-mode.nvim",
    keys = {
      { "<leader>zz", "<Cmd>ZenMode<CR>", mode = "n", desc = "[Z]en [M]ode" }
    },
    config = function()
      require("zen-mode").setup({
        window = {
          backdrop = 0.8,
          width = 0.58,
        }
      })
    end
  },

  -- VimIlluminate
  { "RRethy/vim-illuminate" },

  {
    "lukas-reineke/indent-blankline.nvim",
    config = function()
      require("indent_blankline").setup({
        char = "┊",
        show_current_context_start = true,
        show_trailing_blankline_indent = false,
      })
    end
  },

  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end
  },

  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup {}
    end
  },

  { "tpope/vim-sleuth" }, -- Detect tabstop and shiftwidth automatically
}
