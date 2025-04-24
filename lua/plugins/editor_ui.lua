return {
  -- command, search input & notification
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify", },
    opts = {
      messages = {
        enabled = true,
      },
      lsp = {
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
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "nil",
          },
          opts = { skip = true },
        },
      },
      presets = {
        command_palette = true,
        long_message_to_split = true,
      }
    },
    config = function(_, opts)
      local notify = require("notify")
      notify.setup({
        render = "wrapped-compact",
        stages = "static",
        timeout = 3000,
      })

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
      local window_height = vim.o.lines - 8
      local col_pos = math.floor(vim.o.columns - window_width - 5)
      local row_pos = math.floor(vim.o.lines / 2 - window_height / 2 - 1)

      require("nvim-tree").setup({
        update_focused_file = {
          enable = true,
        },
        view = {
          float = {
            enable = false,
            open_win_config = {
              relative = "editor",
              -- style = "minimal",
              -- border = "shadow",
              border = "rounded",
              width = window_width,
              height = window_height,
              col = col_pos,
              row = row_pos,
            },
          },
          side = "right",
          width = window_width,
        },
        actions = {
          open_file = {
            resize_window = true,
            quit_on_open = true,
          }
        }
      })
    end
  },

  -- Tabs & Buffers
  {
    'akinsho/bufferline.nvim',
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
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      local highlight = {
        "DarkGray"
        -- "RainbowRed",
        -- "RainbowYellow",
        -- "RainbowBlue",
        -- "RainbowOrange",
        -- "RainbowGreen",
        -- "RainbowViolet",
        -- "RainbowCyan",
      }
      local hooks = require "ibl.hooks"
      -- create the highlight groups in the highlight setup hook, so they are reset
      -- every time the colorscheme changes
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        -- vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
        -- vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
        -- vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
        -- vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
        -- vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
        -- vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
        -- vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
        vim.api.nvim_set_hl(0, "DarkGray", { fg = "#444444" })
      end)
      require("ibl").setup({
        indent = { highlight = highlight, char = "│" },
        -- indent = { highlight = highlight, char = "" },
        scope = { enabled = false, },
      })
    end
  },

  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")

      harpoon:setup()

      vim.keymap.set("n", "<A-a>", function() harpoon:list():add() end)
      vim.keymap.set("n", "<A-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

      vim.keymap.set("n", "<leader>1", function() harpoon:list():select(1) end)
      vim.keymap.set("n", "<leader>2", function() harpoon:list():select(2) end)
      vim.keymap.set("n", "<leader>3", function() harpoon:list():select(3) end)
      vim.keymap.set("n", "<leader>4", function() harpoon:list():select(4) end)
      vim.keymap.set("n", "<leader>5", function() harpoon:list():select(5) end)
      vim.keymap.set("n", "<leader>6", function() harpoon:list():select(6) end)
      vim.keymap.set("n", "<leader>7", function() harpoon:list():select(7) end)
      vim.keymap.set("n", "<leader>8", function() harpoon:list():select(8) end)
      vim.keymap.set("n", "<leader>9", function() harpoon:list():select(9) end)

      vim.keymap.set("n", "<A-f>", function() harpoon:list():prev() end, { desc = "Harpoon: Previous", noremap = true })
      vim.keymap.set("n", "<A-g>", function() harpoon:list():next() end, { desc = "Harpoon: Next", noremap = true })
    end
  }
}
