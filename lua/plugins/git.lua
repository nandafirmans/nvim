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
		cmd = { "DiffviewOpen", "DiffviewFileHistory" },
		opts = function()
			-- q closes Diffview and, when the agent hub is open, returns to it.
			local function close()
				vim.cmd("DiffviewClose")
				local ok, agents = pcall(require, "agents")
				if ok and agents.is_open() then
					agents.open()
				end
			end
			local q = { "n", "q", close, { desc = "Close Diffview" } }
			return {
				keymaps = {
					view = { q },
					file_panel = { q },
					file_history_panel = { q },
				},
			}
		end,
		keys = {
			{ "<leader>dd", "<Cmd>DiffviewOpen<CR>", mode = "n" },
			{ "<leader>dr", "<Cmd>DiffviewRefresh<CR>", mode = "n" },
			{ "<leader>df", "<Cmd>DiffviewFileHistory %<CR>", mode = "n" },
			{ "<leader>dF", "<Cmd>DiffviewFileHistory % --first-parent<CR>", mode = "n" },
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
