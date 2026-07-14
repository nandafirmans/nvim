return {
	{
		"christoomey/vim-tmux-navigator",
		lazy = false,
		init = function()
			vim.g.tmux_navigator_no_mappings = 1
		end,
	},

	{
		"paulbkim-dev/vim-herdr-navigation",
		lazy = false,
		dependencies = { "christoomey/vim-tmux-navigator" },
		init = function()
			vim.g.tmux_navigator_no_mappings = 1
		end,
		config = function(plugin)
			dofile(plugin.dir .. "/editor/nvim.lua")
		end,
	},

	{
		"famiu/bufdelete.nvim",
		lazy = false,
		keys = {
			{
				"<A-w>",
				function()
					require("bufdelete").bufdelete(0, false)
				end,
				mode = "n",
				desc = "Buffer Close",
			},
		},
	},

	-- Auto close tag
	{
		"windwp/nvim-ts-autotag",
		config = function()
			require("nvim-ts-autotag").setup()
		end,
	},

	-- Auto pair char
	{
		"windwp/nvim-autopairs",
		config = function()
			require("nvim-autopairs").setup({
				disable_filetype = { "TelescopePrompt", "vim" },
			})
		end,
	},

	-- Multi Cursor
	{
		"mg979/vim-visual-multi",
		branch = "master",
	},

	-- Show hex color and rgb
	{
		"norcalli/nvim-colorizer.lua",
		config = function()
			require("colorizer").setup()
		end,
	},

	-- ZenMode
	{
		"folke/zen-mode.nvim",
		keys = {
			{ "<leader>zz", "<Cmd>ZenMode<CR>", mode = "n", desc = "[Z]en [M]ode" },
		},
		opts = {
			window = {
				backdrop = 0.8,
				width = 0.8,
			},
			plugins = {
				options = {

					laststatus = 0,
				},
				tmux = { enabled = false },
			},
		},
	},

	-- VimIlluminate
	{
		"RRethy/vim-illuminate",
		lazy = false,
	},

	{
		"numToStr/Comment.nvim",
		config = function()
			require("Comment").setup()
		end,
	},

	{
		"folke/todo-comments.nvim",
		lazy = false,
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("todo-comments").setup()
		end,
	},

	{
		"tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
		lazy = false,
	},
}
