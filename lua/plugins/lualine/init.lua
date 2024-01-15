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
        disabled_filetypes = {},
        always_divide_middle = true,
        globalstatus = true,
        refresh = {
          statusline = 100,
          tabline = 100,
          winbar = 100,
        },
      },
      sections = {
        lualine_x = {
          -- require("auto-session.lib").current_session_name,
          {
            'filename',
            path = 1,
            file_status = true
          },
          'encoding',
          'fileformat',
          'filetype'
        },
      },
    })

    lualine_util.init_recording_event()
    lualine_util.init_toggle_buffers_and_tab()
  end
}
