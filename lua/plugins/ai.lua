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
					require("sidekick.cli").toggle({ name = "opencode", focus = true })
				end,
				mode = { "n" },
				desc = "Select CLI",
			},
			{
				"<leader>O",
				function()
					require("sidekick.cli").send({
						msg = "{file}",
						name = "opencode",
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
						name = "opencode",
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
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		lazy = false,
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
			{
				-- support for image pasting
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					-- recommended settings
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
						-- required for Windows users
						use_absolute_path = true,
					},
				},
			},
			{
				-- Make sure to set this up properly if you have lazy=true
				"MeanderingProgrammer/render-markdown.nvim",
				opts = {
					file_types = { "markdown", "Avante" },
				},
				ft = { "markdown", "Avante" },
			},
		},
		opts = {
			provider = "copilot",
			auto_suggestions_provider = "copilot",
			providers = {
				copilot = {
					model = "claude-opus-4.5",
				},
			},
		},
		build = (function()
			if jit.os == "Windows" then
				return "pwsh -NoProfile Build.ps1"
			else
				return "make"
			end
		end)(),
	},
}
