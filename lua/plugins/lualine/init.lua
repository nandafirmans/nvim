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
        -- section_separators = { left = "", right = "" },
        -- component_separators = '|',
        section_separators = { left = "", right = "" },
        component_separators = '',
        always_divide_middle = true,
        -- disabled_filetypes = {},
        -- globalstatus = true,
        disabled_filetypes = {
          statusline = { 'help', 'startify', 'dashboard', 'packer', 'neogitstatus', 'NvimTree', 'Trouble', 'qf', 'copilot-chat', 'Avante', 'AvanteSelectedFiles', 'AvanteInput' },
          winbar = { 'help', 'startify', 'dashboard', 'packer', 'neogitstatus', 'NvimTree', 'Trouble', 'qf', }
        },
        refresh = {
          statusline = 100,
          tabline = 100,
          winbar = 100,
        },
      },
      sections = {
        lualine_x = {
          -- {
          --   'filename',
          --   path = 4,
          --   file_status = true
          -- },
          -- require("auto-session.lib").current_session_name,
          'encoding',
          'fileformat',
          'filetype'
        },
      },
    })

    lualine_util.init_recording_event()

    -- NOTE: comments out to show buffers on startup
    lualine_util.init_toggle_buffers_and_tab()
  end
}
