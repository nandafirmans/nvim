return {

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
      require("auto-session").setup({
        pre_save_cmds = { "tabdo NvimTreeClose", "tabdo DiffviewClose" },
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
      require("zen-mode").setup({})
    end
  },

  -- VimIlluminate
  { "RRethy/vim-illuminate" },

  -- Git related plugins
  { "tpope/vim-fugitive" },
  { "tpope/vim-rhubarb" },

  {
    "lewis6991/gitsigns.nvim",
    lazy = false,
    keys = {
      {
        "<leader>b",
        "<Cmd>Gitsigns toggle_current_line_blame<CR>",
        mode = "n",
      },
    },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
      })
    end
  },

  -- Git Diffview
  {
    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    keys = {
      { "<leader>dd",  "<Cmd>DiffviewOpen<CR>",          mode = "n", },
      { "<leader>dr",  "<Cmd>DiffviewRefresh<CR>",       mode = "n", },
      { "<leader>dhf", "<Cmd>DiffviewFileHistory %<CR>", mode = "n", },
      { "<leader>dh",  "<Cmd>DiffviewFileHistory<CR>",   mode = "n", },
      { "<leader>dc",  "<Cmd>DiffviewClose<CR>",         mode = "n", },
    }
  },

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
