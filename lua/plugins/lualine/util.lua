local M = {}

M.show_macro_recording = function()
  local recording_register = vim.fn.reg_recording()
  if recording_register == "" then
    return ""
  else
    return "Recording @" .. recording_register
  end
end

M.init_recording_event = function()
  local lualine = require("lualine")

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

local buffers = {
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
    active = "lualine_a_normal",
    -- inactive = "lualine_a_inactive",
    -- active = "lualine_a_insert",
    -- active = "lualine_c_active",
  },
  symbols = {
    modified = " ●",
    alternate_file = "",
    directory = "",
  },
}

M.show_lualine_buffers = function()
  require("lualine").setup({
    sections = {
      lualine_a = {
        buffers,
      },
      lualine_b = {
        {
          "macro-recording",
          fmt = M.show_macro_recording,
        },
      },
      lualine_c = {
        'diagnostics',
        'diff',
      },
      lualine_y = { 'progress', 'branch' },
      lualine_z = { 'mode' }
    }
  })
end

M.hide_lualine_buffers = function()
  require("lualine").setup({
    sections = {
      lualine_a = {
        'mode',
      },
      lualine_b = {
        'branch',
        {
          "macro-recording",
          fmt = M.show_macro_recording,
        },
      },
      lualine_c = {
        {
          'filename',
          -- path = 4,
          path = 0,
          file_status = true
        },
        'diagnostics',
        'diff',
      },
      lualine_y = { 'progress' },
      lualine_z = { 'location' }
    }
  })
end


function TOGGLE_TABLINE()
  if vim.o.showtabline == 0 then
    vim.o.showtabline = 2
    -- M.hide_lualine_buffers()
  else
    vim.o.showtabline = 0
    -- M.show_lualine_buffers()
  end
end

M.init_toggle_buffers_and_tab = function()
  -- NOTE: uncomment to show buffers on startup
  -- M.show_lualine_buffers()

  M.hide_lualine_buffers()

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      TOGGLE_TABLINE()
    end,
  })
end


return M
