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

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    keys = {
      {
        "<leader>cco",
        mode = { "v", "n" },
        function()
          require("CopilotChat").open()
        end,
        desc = "CopilotChat - Open chat",
      },
      {
        "<leader>ccr",
        mode = { "v", "n" },
        function()
          require("CopilotChat").reset()
        end,
        desc = "CopilotChat - Reset",
      },
      {
        "<leader>ccq",
        mode = { "v", "n" },
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            local selection
            if vim.fn.visualmode() ~= '' then
              selection = require("CopilotChat.select").visual
            else
              selection = require("CopilotChat.select").buffer
            end
            require("CopilotChat").ask(input, {
              selection = selection
            })
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
      {
        "<leader>cch",
        mode = { "v", "n" },
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.help_actions())
        end,
        desc = "CopilotChat - Help actions",
      },
      {
        "<leader>ccp",
        mode = { "v", "n" },
        function()
          local actions = require("CopilotChat.actions")
          local selection
          if vim.fn.visualmode() ~= '' then
            selection = require("CopilotChat.select").visual
          else
            selection = require("CopilotChat.select").buffer
          end
          require("CopilotChat.integrations.telescope").pick(actions.prompt_actions({
            selection = selection
          }))
        end,
        desc = "CopilotChat - Prompt actions",
      },
    },
    opts = {
      -- default window options
      window = {
        layout = 'float',       -- 'vertical', 'horizontal', 'float'
        -- Options below only apply to floating windows
        relative = 'editor',    -- 'editor', 'win', 'cursor', 'mouse'
        border = 'single',      -- 'none', single', 'double', 'rounded', 'solid', 'shadow'
        width = 0.8,            -- fractional width of parent
        height = 0.6,           -- fractional height of parent
        row = nil,              -- row position of the window, default is centered
        col = nil,              -- column position of the window, default is centered
        title = 'Copilot Chat', -- title of chat window
        footer = nil,           -- footer of chat window
        zindex = 1,             -- determines if window is on top or below other floating windows
      },
    }
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
