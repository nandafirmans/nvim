return {
	{
		"dmtrKovalenko/fff.nvim",
		build = function()
			require("fff.download").download_or_build_binary()
		end,
		lazy = false,
		keys = {
			{
				"<leader>ff",
				function()
					require("fff").find_files()
				end,
				desc = "[F]ind [F]iles (fff.nvim)",
			},
			{
				"<leader>fg",
				function()
					require("fff").live_grep()
				end,
				desc = "[F]ind by [G]rep (fff.nvim)",
			},
		},
		opts = {
			prompt = " ",
			layout = {
				prompt_position = "top",
			},
		},
	},
}
