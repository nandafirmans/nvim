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
    'famiu/bufdelete.nvim',
    lazy = false,
    keys = {
      {
        "<A-w>",
        function()
          require('bufdelete').bufdelete(0, false)
        end,
        mode = "n",
        desc = "Buffer Close"
      }
    },
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
    opts = {
      window = {
        backdrop = 0.8,
        width = 0.58,
      },
    },
  },

  -- VimIlluminate
  {
    "RRethy/vim-illuminate",
    lazy = false,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup({
        indent = {
          char = "▏",
          -- char = "┊",
        },
        scope = {
          enabled = false,
        },
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
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("todo-comments").setup()
    end
  },

  {
    "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
    lazy = false,
  },
}
