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
  {
    "RRethy/vim-illuminate",
    lazy = false,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    version = "2.20.8",
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

  -- {
  --   "echasnovski/mini.animate",
  --   event = "VeryLazy",
  --   opts = function()
  --     -- don't use animate when scrolling with the mouse
  --     local mouse_scrolled = false
  --     for _, scroll in ipairs({ "Up", "Down" }) do
  --       local key = "<ScrollWheel" .. scroll .. ">"
  --       vim.keymap.set({ "", "i" }, key, function()
  --         mouse_scrolled = true
  --         return key
  --       end, { expr = true })
  --     end
  --
  --     local animate = require("mini.animate")
  --     return {
  --       resize = {
  --         timing = animate.gen_timing.linear({ duration = 100, unit = "total" }),
  --       },
  --       scroll = {
  --         timing = animate.gen_timing.linear({ duration = 150, unit = "total" }),
  --         subscroll = animate.gen_subscroll.equal({
  --           predicate = function(total_scroll)
  --             if mouse_scrolled then
  --               mouse_scrolled = false
  --               return false
  --             end
  --             return total_scroll > 1
  --           end,
  --         }),
  --       },
  --     }
  --   end,
  -- }
}
