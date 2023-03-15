return {
  {
    -- LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    dependencies = {
      -- Automatically install LSPs to stdpath for neovim
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",

      -- Useful status updates for LSP
      "j-hui/fidget.nvim",

      -- Additional lua configuration, makes nvim stuff amazing
      "folke/neodev.nvim",
    },
  },

  -- Flutter
  {
    'akinsho/flutter-tools.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },

  {
    -- Autocompletion
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      -- Snippet
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
  },


  {
    "dsznajder/vscode-es7-javascript-react-snippets",
    build = "yarn install --frozen-lockfile && yarn compile",
  },

  -- VSCode like picktogram
  { "onsails/lspkind.nvim" },

  {
    -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    build = function()
      pcall(require("nvim-treesitter.install").update({ with_sync = true }))
    end,
  },

  {
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "glepnir/lspsaga.nvim",
    branch = "main",
    dependencies = {
      { "nvim-tree/nvim-web-devicons" },
      --Please make sure you install markdown and markdown_inline parser
      { "nvim-treesitter/nvim-treesitter" },
    },
  },

  {
    "nvim-tree/nvim-tree.lua",
    tag = "nightly", -- optional, updated every week. (see issue #1193)
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>n", "<Cmd>NvimTreeToggle<CR>", mode = "n" }
    },
    config = function()
      require("nvim-tree").setup({
        update_focused_file = {
          enable = true,
        },
        view = {
          side = "left",
          width = 40,
        },
        actions = {
          open_file = {
            resize_window = true
          }
        }
      })

      local nvimTreeApi = require('nvim-tree.api');
      local nvimTreeEvent = nvimTreeApi.events.Event;
      local bufferlineApi = require('bufferline.api')

      local function getTreeSize()
        return require 'nvim-tree.view'.View.width
      end

      nvimTreeApi.events.subscribe(nvimTreeEvent.TreeOpen, function()
        bufferlineApi.set_offset(getTreeSize())
      end)

      nvimTreeApi.events.subscribe(nvimTreeEvent.Resize, function(size)
        bufferlineApi.set_offset(size)
      end)

      nvimTreeApi.events.subscribe(nvimTreeEvent.TreeClose, function()
        bufferlineApi.set_offset(0)
      end)
    end
  },

  {
    "romgrk/barbar.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },

  -- AutoSession & SessionLens
  {
    "rmagatti/auto-session",
    config = function()
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
      require("auto-session").setup({
        pre_save_cmds = { "tabdo NvimTreeClose", "tabdo DiffviewClose" },
      })
    end
  },
  {
    "rmagatti/session-lens",
    dependencies = {
      "rmagatti/auto-session",
      "nvim-telescope/telescope.nvim"
    },
    keys = {
      { "<leader>ss", "<Cmd>SearchSession<CR>",      mode = "n", desc = "[S]earch [S]ession" },
      { "<leader>sd", "<Cmd>Autosession delete<CR>", mode = "n", desc = "[S]ession [D]elete" }
    },
    config = function()
      require("session-lens").setup({})
    end
  },

  -- Git Diffview
  {
    "sindrets/diffview.nvim",
    dependencies = "nvim-lua/plenary.nvim",
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
    config = function()
      require("zen-mode").setup {}
    end
  },

  -- Todo Highlight
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- FineCmdline
  {
    'VonHeikemen/fine-cmdline.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    keys = {
      { ":", "<Cmd>FineCmdline<CR>", mode = "n", noremap = true }
    },
    config = function()
      require('fine-cmdline').setup({
        cmdline = {
          prompt = ' :'
        },
        popup = {
          size = {
            width = '60%'
          },
          border = {
            text = {
              top = " Cmdline "
            },
          },
          win_options = {
            winhighlight = "Normal:Normal,FloatBorder:SpecialChar",
          },
        },
      })
    end
  },

  -- SearchBox
  {
    'VonHeikemen/searchbox.nvim',
    dependencies = { 'MunifTanjim/nui.nvim' },
    keys = {
      { "/",     "<Cmd>SearchBoxMatchAll<CR>", mode = "n", noremap = true },
      { "<A-c>", "<Cmd>SearchBoxClear<CR>",    mode = "n", noremap = true }
    },
    config = function()
      require('searchbox').setup({
        defaults = {
          clear_matches = false,
          show_matches = true,
        },
        popup = {
          win_options = {
            winhighlight = "Normal:Normal,FloatBorder:SpecialChar",
          },
        },
      })
    end
  },

  -- VimIlluminate
  { "RRethy/vim-illuminate" },

  -- ToggleTerm
  { "akinsho/toggleterm.nvim" },

  -- Git related plugins
  { "tpope/vim-fugitive" },
  { "tpope/vim-rhubarb" },
  { "lewis6991/gitsigns.nvim" },

  { "nvim-lualine/lualine.nvim" },           -- Fancier statusline
  { "lukas-reineke/indent-blankline.nvim" }, -- Add indentation guides even on blank lines
  { "numToStr/Comment.nvim" },               -- "gc" to comment visual regions/lines
  { "tpope/vim-sleuth" },                    -- Detect tabstop and shiftwidth automatically

  -- Fuzzy Finder (files, lsp, etc)
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim", }
  },

  -- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    cond = vim.fn.executable("make") == 1
  },

  -- Telescope File Browser
  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim", },
  },
}
