return {
	{
		"nvim-pack/nvim-spectre",
		lazy = false,
		dependencies = "nvim-lua/plenary.nvim",
		keys = {
			{
				"<leader>F",
				'<CMD>lua require("spectre").toggle()<CR>',
				mode = "n",
				desc = "Toggle Spectre",
			},
			{
				"<leader>F",
				'<ESC><CMD>lua require("spectre").open_visual()<CR>',
				mode = "v",
				desc = "Search Selected Text",
			},
			{
				"<leader>FF",
				'<CMD>lua require("spectre").open_file_search({ select_word = true })<CR>',
				mode = "n",
				desc = "Search Current File",
			},
		},
		config = function()
			require("spectre").setup({
				is_block_ui_break = true,
			})
		end,
	},
}
