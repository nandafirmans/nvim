return {
	{
		"nvim-pack/nvim-spectre",
		lazy = false,
		dependencies = "nvim-lua/plenary.nvim",
		keys = {
			{
				"<C-f>",
				'<CMD>lua require("spectre").toggle()<CR>',
				mode = "n",
				desc = "Toggle Spectre",
			},
			{
				"<C-f>",
				'<ESC><CMD>lua require("spectre").open_visual()<CR>',
				mode = "v",
				desc = "Search Selected Text",
			},
		},
		config = function()
			require("spectre").setup({
				is_block_ui_break = true,
			})
		end,
	},
}
