local M = {}
local uv = vim.uv or vim.loop

local disabled_filetypes = {
	"help",
	"startify",
	"dashboard",
	"packer",
	"neogitstatus",
	"NvimTree",
	"Trouble",
	"qf",
	"copilot-chat",
}

M.options = function()
	return {
		theme = "auto",
		icons_enabled = true,
		section_separators = { left = "", right = "" },
		component_separators = "",
		always_divide_middle = true,
		disabled_filetypes = {
			statusline = disabled_filetypes,
			winbar = disabled_filetypes,
		},
		refresh = {
			statusline = 100,
			tabline = 100,
			winbar = 100,
		},
	}
end

M.show_macro_recording = function()
	local recording_register = vim.fn.reg_recording()

	if recording_register == "" then
		return ""
	end

	return "Recording @" .. recording_register
end

local buffers = {
	"buffers",
	show_filename_only = true,
	hide_filename_extension = false,
	show_modified_status = true,
	max_length = vim.o.columns / 2,
	filetype_names = {
		TelescopePrompt = "Telescope",
		dashboard = "Dashboard",
		packer = "Packer",
		fzf = "FZF",
		alpha = "Alpha",
		NvimTree = "NvimTree",
	},
	buffers_color = {
		inactive = "lualine_c_normal",
		active = "lualine_a_normal",
	},
	symbols = {
		modified = " ●",
		alternate_file = "",
		directory = "",
	},
}

local function refresh_statusline()
	require("lualine").refresh({
		place = { "statusline" },
	})
end

local function macro_recording_component()
	return {
		"macro-recording",
		fmt = M.show_macro_recording,
	}
end

M.init_recording_event = function()
	vim.api.nvim_create_autocmd("RecordingEnter", {
		callback = refresh_statusline,
	})

	vim.api.nvim_create_autocmd("RecordingLeave", {
		callback = function()
			local timer = uv.new_timer()

			if timer then
				timer:start(
					50,
					0,
					vim.schedule_wrap(function()
						refresh_statusline()
						timer:stop()
						timer:close()
					end)
				)
			end
		end,
	})
end

M.show_lualine_buffers = function()
	require("lualine").setup({
		options = M.options(),
		winbar = {
			lualine_a = {
				buffers,
			},
			lualine_b = {
				macro_recording_component(),
			},
			lualine_c = {
				"branch",
				"diagnostics",
				"diff",
			},
			lualine_y = { "progress", },
			lualine_z = { "mode" },
		},
	})
end

M.hide_lualine_buffers = function()
	require("lualine").setup({
		options = M.options(),
		winbar = {
			lualine_a = {
				{
					"filename",
					path = 0,
					file_status = true,
				},
			},
			lualine_b = {
				"branch",
				"diagnostics",
				"diff",
			},
			lualine_c = {
				macro_recording_component(),
			},
			lualine_y = { "location" },
			lualine_z = { "mode" },
		},
	})
end

M.toggle_tabline = function()
	if vim.o.showtabline == 0 then
		vim.o.showtabline = 2
	else
		vim.o.showtabline = 0
	end
end

M.init_toggle_buffers_and_tab = function()
	M.hide_lualine_buffers()

	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			M.toggle_tabline()
		end,
	})
end

return M
