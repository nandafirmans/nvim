return {
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{ "<leader>n", "<Cmd>NvimTreeToggle<CR>", mode = "n", desc = "Toggle File Explorer" },
		},
		config = function()
			local function open_win_config()
				local screen_width = vim.opt.columns:get()
				local screen_height = vim.opt.lines:get()
				local tree_width = 80
				local tree_height = math.floor(tree_width * screen_height / screen_width) + 20

				return {
					border = "rounded",
					relative = "editor",
					width = tree_width,
					height = tree_height,
					col = (screen_width - tree_width) / 2,
					row = (screen_height - tree_height) / 2,
				}
			end

			require("nvim-tree").setup({
				update_focused_file = {
					enable = true,
				},
				view = {
					float = {
						enable = true,
						open_win_config = open_win_config,
					},
					side = "right",
					width = 50,
				},
				actions = {
					open_file = {
						resize_window = true,
						quit_on_open = true,
					},
				},
				filters = {
					git_ignored = false,
				},
			})
		end,
	},
}
