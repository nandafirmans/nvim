return {
  "nvim-lualine/lualine.nvim",
  lazy = false,
  keys = {
    {
      "<leader>t",
      ":lua TOGGLE_TABLINE()<CR>",
      mode = "n",
      desc = "Toggle Tabline"
    }
  },
  config = function()
    local lualine_util = require("plugins.lualine.util")

    require("lualine").setup({
      options = {
        theme = "auto",
        icons_enabled = true,
        section_separators = { left = "", right = "" },
        component_separators = '',
        always_divide_middle = true,
        -- disabled_filetypes = {},
        -- globalstatus = true,
        disabled_filetypes = {
          statusline = { 'help', 'startify', 'dashboard', 'packer', 'neogitstatus', 'NvimTree', 'Trouble', 'qf', 'copilot-chat', 'Avante', 'AvanteTodos', 'AvanteSelectedFiles', 'AvanteInput' },
          winbar = { 'help', 'startify', 'dashboard', 'packer', 'neogitstatus', 'NvimTree', 'Trouble', 'qf', 'copilot-chat', 'Avante', 'AvanteTodos', 'AvanteSelectedFiles', 'AvanteInput' }
        },
        refresh = {
          statusline = 100,
          tabline = 100,
          winbar = 100,
        },
      },
      sections = {},
      inactive_sections = {},
      winbar = {
        lualine_x = {
          'encoding',
          'fileformat',
          'filetype'
        },
      },
      inactive_winbar = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
          {
            'filename',
            path = 4,
            file_status = true
          }
        },
        lualine_x = {},
        lualine_y = {},
        lualine_z = {}
      },
    })

    lualine_util.init_recording_event()

    -- NOTE: comments out to show buffers on startup
    lualine_util.init_toggle_buffers_and_tab()
  end
}
