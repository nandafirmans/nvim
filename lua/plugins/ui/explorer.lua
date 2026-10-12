return {
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{
				"<leader>n",
				function()
					-- Root at this tab's folder, so each agent workspace tab shows its own project.
					require("nvim-tree.api").tree.toggle({ path = vim.fn.getcwd(), find_file = true })
				end,
				mode = "n",
				desc = "Toggle File Explorer",
			},
		},
		config = function()
			local function open_win_config()
				local screen_width = vim.opt.columns:get()
				local screen_height = vim.opt.lines:get()
				local tree_width = 80
				-- local tree_height = math.floor(tree_width * screen_height / screen_width) + 20
				local tree_height = 80

				return {
					border = "rounded",
					relative = "editor",
					width = tree_width,
					height = tree_height,
					-- col = (screen_width - tree_width) / 2,
					col = screen_width - tree_width,
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
