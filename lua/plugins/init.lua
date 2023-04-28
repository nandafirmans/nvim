return {

  {
    "github/copilot.vim",
    lazy = false,
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
        ["lua"] = true,
        ["rust"] = false,
        ["c"] = false,
        ["c#"] = false,
        ["c++"] = false,
        ["go"] = true,
        ["python"] = false,
      }
    end
  },

  -- {
  --   "jackMort/ChatGPT.nvim",
  --   event = "VeryLazy",
  --   config = function()
  --     require("chatgpt").setup()
  --   end,
  --   dependencies = {
  --     "MunifTanjim/nui.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "nvim-telescope/telescope.nvim"
  --   }
  -- },

  {
    "Bryley/neoai.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    cmd = {
      "NeoAI",
      "NeoAIOpen",
      "NeoAIClose",
      "NeoAIToggle",
      "NeoAIContext",
      "NeoAIContextOpen",
      "NeoAIContextClose",
      "NeoAIInject",
      "NeoAIInjectCode",
      "NeoAIInjectContext",
      "NeoAIInjectContextCode",
    },
    keys = {
      { "<leader>as", desc = "summarize text" },
      { "<leader>ag", desc = "generate git message" },
    },
    config = function()
      require("neoai").setup({
        -- Options go here
      })
    end,
  },

  -- {
  --   "zbirenbaum/copilot.lua",
  --   cmd = "Copilot",
  --   event = "InsertEnter",
  --   config = function()
  --     require("copilot").setup({
  --       suggestion = { enabled = false },
  --       panel = { enabled = false },
  --     })
  --   end,
  -- },
  --
  -- {
  --   "zbirenbaum/copilot-cmp",
  --   dependencies = { "copilot.lua" },
  --   config = function()
  --     require("copilot_cmp").setup({
  --       formatters = {
  --         label = require("copilot_cmp.format").format_label_text,
  --         insert_text = require("copilot_cmp.format").format_insert_text,
  --         preview = require("copilot_cmp.format").deindent,
  --       },
  --     })
  --   end
  -- },

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
    config = function()
      -- local has_words_before = function()
      --   if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then return false end
      --   local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      --   return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
      -- end

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
            mode = 'symbol',
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
            -- if cmp.visible() and has_words_before() then
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
          -- { name = "copilot",  group_index = 2 },
          { name = "nvim_lsp", group_index = 2 },
          { name = "luasnip",  group_index = 2 },
          { name = "path",     group_index = 2 },
        },
      })
    end
  },

  {
    "dsznajder/vscode-es7-javascript-react-snippets",
    build = "yarn install --frozen-lockfile && yarn compile",
  },

  -- VSCode like picktogram
  { "onsails/lspkind.nvim" },

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
          side = "right",
          width = 60,
        },
        actions = {
          open_file = {
            resize_window = true
          }
        }
      })

      -- local nvimTreeApi = require('nvim-tree.api');
      -- local nvimTreeEvent = nvimTreeApi.events.Event;
      -- local bufferlineApi = require('bufferline.api')
      --
      -- local function getTreeSize()
      --   return require 'nvim-tree.view'.View.width
      -- end
      --
      -- nvimTreeApi.events.subscribe(nvimTreeEvent.TreeOpen, function()
      --   bufferlineApi.set_offset(getTreeSize())
      -- end)
      --
      -- nvimTreeApi.events.subscribe(nvimTreeEvent.Resize, function(size)
      --   bufferlineApi.set_offset(size)
      -- end)
      --
      -- nvimTreeApi.events.subscribe(nvimTreeEvent.TreeClose, function()
      --   bufferlineApi.set_offset(0)
      -- end)
    end
  },

  {
    "romgrk/barbar.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },

  -- AutoSession & SessionLens
  {
    "rmagatti/auto-session",
    lazy = false,
    keys = {
      { "<leader>sd", "<Cmd>Autosession delete<CR>", mode = "n", desc = "[S]ession [D]elete" }
    },
    config = function()
      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

      require("auto-session").setup({
        pre_save_cmds = { "tabdo NvimTreeClose", "tabdo DiffviewClose" },
      })

      vim.keymap.set("n", "<leader>ss", require("auto-session.session-lens").search_session, { silent = true })
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

  -- Auto close buffer on inactivity
  -- {
  --   "chrisgrieser/nvim-early-retirement",
  --   event = "VeryLazy",
  --   opts = {
  --     -- if a buffer has been inactive for this many minutes, close it
  --     retirementAgeMins = 20,
  --     -- filetypes to ignore
  --     ignoredFiletypes = {},
  --     -- will not close the alternate file
  --     ignoreAltFile = true,
  --     -- will ignore buffers with unsaved changes. If false, the buffers will
  --     -- automatically be written and then closed.
  --     ignoreUnsavedChangesBufs = true,
  --     -- ignore non-empty buftypes, e.g. terminal buffers
  --     ignoreSpecialBuftypes = true,
  --     -- uses vim.notify for plugins like nvim-notify
  --     notificationOnAutoClose = false,
  --   },
  --   config = function(_, opts)
  --     require("early-retirement").setup(opts)
  --   end,
  -- },

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
          section_separators = { left = "", right = "" },
          component_separators = "|",
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
            require("auto-session.lib").current_session_name,
            { 'filename', path = 0, file_status = true },
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
