return {
	{
		"folke/snacks.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			picker = {},
			terminal = {},
		},
		keys = {
			{
				"<A-T>",
				function()
					Snacks.terminal.toggle()
				end,
				mode = { "n", "t" },
				desc = "Toggle Terminal",
			},
		},
	},
}
