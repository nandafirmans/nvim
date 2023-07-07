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
          width = 50,
        },
        actions = {
          open_file = {
            resize_window = true
          }
        }
      })
    end
  },

  {
    'akinsho/bufferline.nvim',
    version = "*",
    lazy = false,
    dependencies = 'nvim-tree/nvim-web-devicons',
    keys = {
      { "<A-.>",  "<Cmd>BufferLineCycleNext<CR>",       mode = "n", desc = "BufferLine Cycle Next" },
      { "<A-,>",  "<Cmd>BufferLineCyclePrev<CR>",       mode = "n", desc = "BufferLine Cycle Prev" },
      { "<C-.>",  "<Cmd>BufferLineMoveNext<CR>",        mode = "n", desc = "BufferLine Move Next" },
      { "<C-,>",  "<Cmd>BufferLineMovePrev<CR>",        mode = "n", desc = "BufferLine Move Prev" },
      { "<A-p>p", "<Cmd>BufferLinePick<CR>",            mode = "n", desc = "BufferLine Pick" },
      { "<A-p>w", "<Cmd>BufferLinePickClose<CR>",       mode = "n", desc = "BufferLine Pick Close" },
      { "<A-s>e", "<Cmd>BufferLineSortByTabs<CR>",      mode = "n", desc = "BufferLine Sort By Tabs" },
      { "<A-s>e", "<Cmd>BufferLineSortByExtension<CR>", mode = "n", desc = "BufferLine Sort By Extension" },
      { "<A-s>d", "<Cmd>BufferLineSortByDirectory<CR>", mode = "n", desc = "BufferLine Sort By Directory" },
      {
        "<A-s>r",
        "<Cmd>BufferLineSortByRelativeDirectory<CR>",
        mode = "n",
        desc = "BufferLine Sort By Relative Directory"
      },
    },
    config = function()
      require("bufferline").setup({
        options = {
          diagnostics = 'nvim_lsp',
          truncate_names = false,
          indicator = {
            style = "none",
          },
          hover = {
            enabled = true,
            delay = 100,
            reveal = { 'close' },
          },
          -- separator_style = 'slant',
          offsets = {
            {
              filetype = "NvimTree",
              text = "File Explorer",
              text_align = "center",
              separator = true
            }
          },
        }
      })
    end
  },

  -- {
  --   "folke/flash.nvim",
  --   event = "VeryLazy",
  --   opts = {},
  --   keys = {
  --     {
  --       "s",
  --       mode = { "n", "x", "o" },
  --       function()
  --         -- default options: exact mode, multi window, all directions, with a backdrop
  --         require("flash").jump()
  --       end,
  --     },
  --     {
  --       "S",
  --       mode = { "n", "o", "x" },
  --       function()
  --         require("flash").treesitter()
  --       end,
  --     },
  --   },
  -- },


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

  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify", },
    config = function()
      require("noice").setup({
        cmdline = {
          format = {
            cmdline = { icon = ">" },
            search_down = { icon = "search [v]" },
            search_up = { icon = "search [^]" },
            filter = { icon = "filter" },
            lua = { icon = "lua" },
            help = { icon = "help" },
          }
        }
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
    dependencies = { "nvim-lua/plenary.nvim", },
    config = function()
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<C-u>"] = false,
              ["<C-d>"] = false,
            },
          },
          path_display = {
            truncate = 3
          }
        },
        pickers = {
          colorscheme = {
            theme = "dropdown",
            enable_preview = true,
          },
          buffers = {
            theme = "dropdown",
            previewer = false,
            path_display = {
              shorten = 2,
              truncate = 3,
            }
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

      require("telescope").load_extension("fzf")
      require("telescope").load_extension("file_browser")
      require("telescope").load_extension("flutter")
    end,
    keys = {
      {
        "<leader>?",
        function() require("telescope.builtin").oldfiles(); end,
        desc = "[?] Find recently opened files"
      },
      {
        "<leader><space>",
        function() require("telescope.builtin").buffers(); end,
        desc = "[ ] Find existing buffers"
      },
      {
        "<leader>f/",
        function()
          require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
            winblend = 10,
            previewer = false,
          }));
        end,
        desc = "[/] Fuzzily search in current buffer]"
      },
      { "<leader>fr", function() require("telescope.builtin").resume(); end,           desc = "[ ] Resume Last Find" },
      { "<leader>ff", function() require("telescope.builtin").find_files(); end,       desc = "[F]ind [F]iles" },
      { "<leader>fh", function() require("telescope.builtin").help_tags(); end,        desc = "[F]ind [H]elp" },
      { "<leader>fw", function() require("telescope.builtin").grep_string(); end,      desc = "[F]ind current [W]ord" },
      { "<leader>fg", function() require("telescope.builtin").live_grep(); end,        desc = "[F]ind by [G]rep" },
      { "<leader>fd", function() require("telescope.builtin").diagnostics(); end,      desc = "[F]ind [D]iagnostics" },
      { "<leader>fc", function() require("telescope.builtin").commands(); end,         desc = "[F]ind [C]ommands" },
      { "<leader>fs", function() require("telescope.builtin").colorscheme(); end,      desc = "[F]ind color[S]chemes" },
      { "<leader>fk", function() require("telescope.builtin").keymaps(); end,          desc = "[F]ind [K]eymaps" },
      { "<leader>ft", "<Cmd>TodoTelescope<CR>",                                        desc = "[F]ind [T]odo" },
      { "<leader>fb", "<Cmd>Telescope file_browser path=%:p:h select_buffer=true<CR>", desc = "[F]ile [B]rowser" },
    }
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
