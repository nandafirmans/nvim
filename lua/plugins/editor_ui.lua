return {
  -- command, search input & notification
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify", },
    opts = {
      -- messages = {
      --   enabled = false,
      -- },
      lsp = {
        -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "written",
          },
          opts = { skip = true },
        },
      },
      -- cmdline = {
      --   format = {
      --     cmdline = { icon = ">" },
      --     search_down = { icon = "search [v]" },
      --     search_up = { icon = "search [^]" },
      --     filter = { icon = "filter" },
      --     lua = { icon = "lua" },
      --     help = { icon = "help" },
      --   }
      -- },
      -- views = {
      --   cmdline_popup = {
      --     position = {
      --       row = 5,
      --       col = "50%",
      --     },
      --     size = {
      --       width = 60,
      --       height = "auto",
      --     },
      --   },
      --   popupmenu = {
      --     relative = "editor",
      --     position = {
      --       row = 8,
      --       col = "50%",
      --     },
      --     size = {
      --       width = 60,
      --       height = 10,
      --     },
      --     border = {
      --       style = "rounded",
      --       padding = { 0, 1 },
      --     },
      --     win_options = {
      --       winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
      --     },
      --   },
      -- },
      presets = {
        command_palette = true,
      }
    },
    config = function(_, opts)
      require("noice").setup(opts)
    end
  },

  -- File Explorer
  {
    "nvim-tree/nvim-tree.lua",
    -- tag = "nightly", -- optional, updated every week. (see issue #1193)
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>n", "<Cmd>NvimTreeToggle<CR>", mode = "n" }
    },
    config = function()
      local window_width = 50
      local window_height = vim.o.lines - 20
      local col_pos = math.floor(vim.o.columns / 2 - window_width / 2)
      -- local col_pos = math.floor(vim.o.columns - window_width - 5)
      local row_pos = math.floor(vim.o.lines / 2 - window_height / 2 - 1)

      require("nvim-tree").setup({
        update_focused_file = {
          enable = true,
        },
        view = {
          float = {
            enable = true,
            open_win_config = {
              relative = "editor",
              border = "rounded",
              width = window_width,
              height = window_height,
              col = col_pos,
              row = row_pos,
            },
          },
          side = "left",
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

  -- Tabs & Buffers
  {
    'akinsho/bufferline.nvim',
    -- version = "*",
    branch = "main",
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
    opts = {
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
    },
    config = function(_, opts)
      require("bufferline").setup(opts)
    end
  },

  {
    "nvim-pack/nvim-spectre",
    lazy = false,
    dependencies = "nvim-lua/plenary.nvim",
    keys = {
      {
        "<leader>F",
        '<CMD>lua require("spectre").toggle()<CR>',
        mode = "n",
        desc = "Toggle Spectre"
      },
      {
        "<leader>F",
        '<ESC><CMD>lua require("spectre").open_visual()<CR>',
        mode = "v",
        desc = "Search Selected Text"
      },
      {
        "<leader>FF",
        '<CMD>lua require("spectre").open_file_search({select_word=true})<CR>',
        mode = "n",
        desc = "Search on current file"
      }
    },
    config = function()
      require('spectre').setup({
        is_block_ui_break = true
      })
    end
  }
}
