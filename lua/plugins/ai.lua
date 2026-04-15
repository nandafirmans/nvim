return {
	{
		"zbirenbaum/copilot.lua",
		requires = {
			"copilotlsp-nvim/copilot-lsp",
			init = function()
				vim.g.copilot_nes_debounce = 500
			end,
		},
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("copilot").setup({
				suggestion = { enabled = false },
				panel = { enabled = false },
			})
		end,
	},
	{
		"zbirenbaum/copilot-cmp",
		dependencies = { "copilot.lua" },
		config = function()
			require("copilot_cmp").setup()
		end,
	},
	{
		"folke/sidekick.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"echasnovski/mini.pick", -- for file_selector provider mini.pick
			"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
			"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
			"ibhagwan/fzf-lua", -- for file_selector provider fzf
			"stevearc/dressing.nvim", -- for input provider dressing
			"folke/snacks.nvim", -- for input provider snacks
			"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
			"zbirenbaum/copilot.lua", -- for providers='copilot'
		},
		opts = {
			cli = {
				mux = {
					enabled = true,
					backend = "tmux",
				},
			},
			nes = {
				enabled = false,
			},
		},
		keys = {
			{
				"<leader>oo",
				function()
					require("sidekick.cli").toggle({ focus = true })
				end,
				mode = { "n" },
				desc = "Select CLI",
			},
			{
				"<leader>O",
				function()
					require("sidekick.cli").send({
						msg = "{file}",
						filter = { installed = true },
					})
				end,
				mode = { "x", "n" },
				desc = "Send This",
			},
			{
				"<leader>oo",
				function()
					require("sidekick.cli").send({
						msg = "{selection}",
						filter = { installed = true },
					})
				end,
				mode = { "x" },
				desc = "Send Visual Selection",
			},
			{
				"<leader>op",
				function()
					require("sidekick.cli").prompt()
				end,
				mode = { "n", "x" },
				desc = "Sidekick Select Prompt",
			},
			{
				"<leader>oc",
				function()
					require("sidekick.cli").toggle({ name = "copilot", focus = true })
				end,
				mode = { "n", "x" },
				desc = "Sidekick Toggle Copilot",
			},
		},
	},
}
