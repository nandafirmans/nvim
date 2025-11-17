return {
	{ "tpope/vim-fugitive" },
	{ "tpope/vim-rhubarb" },

	{
		"lewis6991/gitsigns.nvim",
		lazy = false,
		keys = {
			{
				"<leader>gb",
				"<Cmd>Gitsigns toggle_current_line_blame<CR>",
				mode = "n",
			},
		},
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "+" },
					change = { text = "~" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
				},
			})

			vim.cmd([[ Gitsigns toggle_current_line_blame ]])
		end,
	},

	{
		"sindrets/diffview.nvim",
		dependencies = "nvim-lua/plenary.nvim",
		keys = {
			{ "<leader>dd", "<Cmd>DiffviewOpen<CR>", mode = "n" },
			{ "<leader>dr", "<Cmd>DiffviewRefresh<CR>", mode = "n" },
			{ "<leader>df", "<Cmd>DiffviewFileHistory % --first-parent<CR>", mode = "n" },
			{ "<leader>dh", "<Cmd>DiffviewFileHistory --first-parent<CR>", mode = "n" },
			{ "<leader>dc", "<Cmd>DiffviewClose<CR>", mode = "n" },
		},
	},

	{
		"akinsho/git-conflict.nvim",
		version = "*",
		config = true,
	},
}
