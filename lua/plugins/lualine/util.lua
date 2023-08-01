local M = {}

M.lualine_config_buffers = {
  "buffers",
  show_filename_only = true,
  hide_filename_extension = false,
  show_modified_status = true,

  -- mode = 2,

  max_length = vim.o.columns * 2 / 3,

  filetype_names = {
    TelescopePrompt = "Telescope",
    dashboard = "Dashboard",
    packer = "Packer",
    fzf = "FZF",
    alpha = "Alpha",
    NvimTree = "NvimTree"
  },

  buffers_color = {
    -- inactive = "lualine_c_normal",
    active = "lualine_a_inactive",
  },
  symbols = {
    modified = " ●",
    alternate_file = "",
    directory = "",
  },
}

M.lualine_config_filename = {
  'filename',
  path = 0,
  file_status = true
}

M.show_macro_recording = function()
  local recording_register = vim.fn.reg_recording()
  if recording_register == "" then
    return ""
  else
    return "Recording @" .. recording_register
  end
end


M.show_lualine_buffers = function()
  require("lualine").setup({
    sections = {
      lualine_c = {
        M.lualine_config_buffers,
      }
    }
  })
end

M.hide_lualine_buffers = function()
  require("lualine").setup({
    sections = {
      lualine_c = {
        M.lualine_config_filename,
      }
    }
  })
end

return M
