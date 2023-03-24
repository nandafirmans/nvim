return {

  {
    "github/copilot.vim",
    config = function()
      vim.g.copilot_no_tab_map = true
      vim.api.nvim_set_keymap("i", "<A-j>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
      vim.g.copilot_filetypes = {
        ["*"] = false,
        ["javascript"] = true,
        ["typescript"] = true,
        ["css"] = true,
        ["scss"] = true,
        ["less"] = true,
        ["html"] = true,
        ["lua"] = false,
        ["rust"] = false,
        ["c"] = false,
        ["c#"] = false,
        ["c++"] = false,
        ["go"] = true,
        ["python"] = false,
      }
    end
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
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
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
          width = 50,
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
      require("zen-mode").setup({})
    end
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

  {
    "lewis6991/gitsigns.nvim",
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

  -- StatusLine
  {
    "nvim-lualine/lualine.nvim",
    config = function()
      local function show_macro_recording()
        local recording_register = vim.fn.reg_recording()
        if recording_register == "" then
          return ""
        else
          return "Recording @" .. recording_register
        end
      end

      local lualine = require("lualine")

      lualine.setup({
        options = {
          theme = "auto",
          -- section_separators = { left = '', right = '' },
          section_separators = { left = "", right = "" },
          component_separators = "|",
          -- component_separators = "┊",
          -- component_separators = { left = "", right = "" },
          -- component_separators = { left = '', right = '' },
          -- disabled_filetypes = { "packer", "NvimTree" },
          disabled_filetypes = {},
          globalstatus = true,
          refresh = {
            statusline = 100,
            tabline = 100,
            winbar = 100,
          },
        },
        sections = {
          lualine_b = {
            'branch', 'diff', 'diagnostics',
            {
              "macro-recording",
              fmt = show_macro_recording
            },
          },
          lualine_c = {
            require("auto-session-library").current_session_name,
            { 'filename', path = 1, file_status = true },
          }
        },
      })

      vim.api.nvim_create_autocmd("RecordingEnter", {
        callback = function()
          lualine.refresh({
            place = { "statusline" },
          })
        end,
      })

      vim.api.nvim_create_autocmd("RecordingLeave", {
        callback = function()
          -- This is going to seem really weird!
          -- Instead of just calling refresh we need to wait a moment because of the nature of
          -- `vim.fn.reg_recording`. If we tell lualine to refresh right now it actually will
          -- still show a recording occuring because `vim.fn.reg_recording` hasn't emptied yet.
          -- So what we need to do is wait a tiny amount of time (in this instance 50 ms) to
          -- ensure `vim.fn.reg_recording` is purged before asking lualine to refresh.
          local timer = vim.loop.new_timer()
          if (timer ~= nil) then
            timer:start(
              50,
              0,
              vim.schedule_wrap(function()
                lualine.refresh({
                  place = { "statusline" },
                })
              end)
            )
          end
        end,
      })
    end
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    config = function()
      require("indent_blankline").setup({
        char = "┊",
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
