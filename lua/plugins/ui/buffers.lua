return {
	{
		"akinsho/bufferline.nvim",
		branch = "main",
		lazy = false,
		dependencies = "nvim-tree/nvim-web-devicons",
		keys = {
			{ "<A-.>", "<Cmd>BufferLineCycleNext<CR>", mode = "n", desc = "BufferLine Cycle Next" },
			{ "<A-,>", "<Cmd>BufferLineCyclePrev<CR>", mode = "n", desc = "BufferLine Cycle Prev" },
			{ "<C-.>", "<Cmd>BufferLineMoveNext<CR>", mode = "n", desc = "BufferLine Move Next" },
			{ "<C-,>", "<Cmd>BufferLineMovePrev<CR>", mode = "n", desc = "BufferLine Move Prev" },
			{ "<A-p>p", "<Cmd>BufferLinePick<CR>", mode = "n", desc = "BufferLine Pick" },
			{ "<A-p>w", "<Cmd>BufferLinePickClose<CR>", mode = "n", desc = "BufferLine Pick Close" },
			{ "<A-s>e", "<Cmd>BufferLineSortByTabs<CR>", mode = "n", desc = "BufferLine Sort By Tabs" },
			{ "<A-s>e", "<Cmd>BufferLineSortByExtension<CR>", mode = "n", desc = "BufferLine Sort By Extension" },
			{ "<A-s>d", "<Cmd>BufferLineSortByDirectory<CR>", mode = "n", desc = "BufferLine Sort By Directory" },
			{
				"<A-s>r",
				"<Cmd>BufferLineSortByRelativeDirectory<CR>",
				mode = "n",
				desc = "BufferLine Sort By Relative Directory",
			},
		},
		opts = {
			options = {
				diagnostics = "nvim_lsp",
				truncate_names = false,
				indicator = {
					style = "none",
				},
				hover = {
					enabled = true,
					delay = 100,
					reveal = { "close" },
				},
				offsets = {
					{
						filetype = "NvimTree",
						text = "File Explorer",
						text_align = "center",
						separator = true,
					},
				},
			},
		},
		config = function(_, opts)
			require("bufferline").setup(opts)
		end,
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		config = function()
			local highlight = {
				"RainbowRed",
				"RainbowYellow",
				"RainbowBlue",
				"RainbowOrange",
				"RainbowGreen",
				"RainbowViolet",
				"RainbowCyan",
			}
			local hooks = require("ibl.hooks")

			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
				vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
				vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
				vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
				vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
				vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
				vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
			end)

			require("ibl").setup({
				indent = {
					char = "│",
				},
				scope = {
					highlight = highlight,
					show_start = false,
					show_end = false,
				},
			})

			hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
		end,
	},
}
