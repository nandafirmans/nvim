local M = {}


M.show_lualine_buffers = function()
  require("lualine").setup({
    sections = {
      lualine_c = {
        {
          "buffers",
          show_filename_only = true,
          hide_filename_extension = false,
          show_modified_status = true,

          -- mode = 2,

          -- max_length = vim.o.columns * 2 / 3,
          max_length = vim.o.columns * 1 / 2,


          filetype_names = {
            TelescopePrompt = "Telescope",
            dashboard = "Dashboard",
            packer = "Packer",
            fzf = "FZF",
            alpha = "Alpha",
            NvimTree = "NvimTree"
          },

          buffers_color = {
            inactive = "lualine_c_normal",
            active = "lualine_a_inactive",
            -- inactive = "lualine_a_inactive",
            -- active = "lualine_a_insert",
          },
          symbols = {
            modified = " ●",
            alternate_file = "",
            directory = "",
          },
        },
        'diagnostics',
        'diff',
      }
    }
  })
end

M.hide_lualine_buffers = function()
  require("lualine").setup({
    sections = {
      lualine_c = {
        {
          'filename',
          path = 0,
          file_status = true
        },
        'diagnostics',
        'diff',
      }
    }
  })
end

M.show_macro_recording = function()
  local recording_register = vim.fn.reg_recording()
  if recording_register == "" then
    return ""
  else
    return "Recording @" .. recording_register
  end
end

return M
