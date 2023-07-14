return {
  -- command, search input & notification
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify", },
    opts = {
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
      cmdline = {
        format = {
          cmdline = { icon = ">" },
          search_down = { icon = "search [v]" },
          search_up = { icon = "search [^]" },
          filter = { icon = "filter" },
          lua = { icon = "lua" },
          help = { icon = "help" },
        }
      },
      views = {
        cmdline_popup = {
          position = {
            row = 5,
            col = "50%",
          },
          size = {
            width = 60,
            height = "auto",
          },
        },
        popupmenu = {
          relative = "editor",
          position = {
            row = 8,
            col = "50%",
          },
          size = {
            width = 60,
            height = 10,
          },
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
          win_options = {
            winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
          },
        },
      },
    },
    config = function(_, opts)
      require("noice").setup(opts)
    end
  },

  -- File Explorer
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

  -- Tabs & Buffers
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
}
