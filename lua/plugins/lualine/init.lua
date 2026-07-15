return {
	"nvim-lualine/lualine.nvim",
	lazy = false,
	keys = {
		{
			"<leader>t",
			function()
				require("plugins.lualine.util").toggle_tabline()
			end,
			mode = "n",
			desc = "Toggle Tabline",
		},
	},
	config = function()
		local lualine_util = require("plugins.lualine.util")

		require("lualine").setup({
			options = lualine_util.options(),
			sections = {
				lualine_x = {
					"encoding",
					"fileformat",
					"filetype",
				},
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = {
					{
						"filename",
						path = 4,
						file_status = true,
					},
				},
				lualine_x = {},
				lualine_y = {},
				lualine_z = {},
			},
			winbar = {},
			inactive_winbar = {},
		})

		lualine_util.init_recording_event()
		lualine_util.init_toggle_buffers_and_tab()
	end,
}
