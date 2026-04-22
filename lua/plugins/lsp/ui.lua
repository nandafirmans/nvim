return {
	{
		"glepnir/lspsaga.nvim",
		branch = "main",
		lazy = false,
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"nvim-treesitter/nvim-treesitter",
		},
		keys = {
			{ "gh", "<Cmd>Lspsaga finder<CR>", mode = "n", desc = "LSP Finder" },
			{ "<leader>ca", "<Cmd>Lspsaga code_action<CR>", mode = { "n", "v" }, desc = "[C]ode [A]ction" },
			{ "<leader>rn", "<Cmd>Lspsaga rename<CR>", mode = "n", desc = "[R]e[N]ame" },
			{ "gp", "<Cmd>Lspsaga peek_definition<CR>", mode = "n", desc = "Peek Definition" },
			{ "gd", "<Cmd>Lspsaga goto_definition<CR>", mode = "n", desc = "[G]o to [D]efinition" },
			{ "<leader>sl", "<Cmd>Lspsaga show_line_diagnostics<CR>", mode = "n", desc = "Show Line Diagnostics" },
			{ "<leader>sc", "<Cmd>Lspsaga show_cursor_diagnostics<CR>", mode = "n", desc = "Show Cursor Diagnostics" },
			{ "<leader>sb", "<Cmd>Lspsaga show_buf_diagnostics<CR>", mode = "n", desc = "Show Buffer Diagnostics" },
			{ "[e", "<Cmd>Lspsaga diagnostic_jump_prev<CR>", mode = "n", desc = "Previous Diagnostic" },
			{ "]e", "<Cmd>Lspsaga diagnostic_jump_next<CR>", mode = "n", desc = "Next Diagnostic" },
			{
				"[E",
				function()
					require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR })
				end,
				mode = "n",
				desc = "Previous Error",
			},
			{
				"]E",
				function()
					require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR })
				end,
				mode = "n",
				desc = "Next Error",
			},
			{ "<Leader>ci", "<Cmd>Lspsaga incoming_calls<CR>", mode = "n", desc = "Incoming Calls" },
			{ "<Leader>co", "<Cmd>Lspsaga outgoing_calls<CR>", mode = "n", desc = "Outgoing Calls" },
			{ "K", "<Cmd>Lspsaga hover_doc<CR>", mode = "n", desc = "Hover Documentation" },
			{ "<A-T>", "<Cmd>Lspsaga term_toggle<CR>", mode = { "n", "t" }, desc = "Toggle Lspsaga Terminal" },
		},
		opts = {
			diagnostic_only_current = true,
			symbol_in_winbar = {
				enable = false,
				hide_keyword = false,
				show_file = true,
				folder_level = 1,
				respect_root = false,
				color_mode = true,
			},
			definition = {
				width = 0.8,
				height = 0.9,
			},
		},
	},
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		keys = {
			{ "<leader>xx", "<Cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics (Trouble)" },
			{ "<leader>xX", "<Cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Buffer Diagnostics (Trouble)" },
			{ "<leader>cs", "<Cmd>Trouble symbols toggle focus=false<CR>", desc = "Symbols (Trouble)" },
			{
				"<leader>cl",
				"<Cmd>Trouble lsp toggle focus=false win.position=right<CR>",
				desc = "LSP Definitions / references / ... (Trouble)",
			},
			{ "<leader>xL", "<Cmd>Trouble loclist toggle<CR>", desc = "Location List (Trouble)" },
			{ "<leader>xQ", "<Cmd>Trouble qflist toggle<CR>", desc = "Quickfix List (Trouble)" },
		},
		config = function()
			require("trouble").setup({
				modes = {
					diagnostics = {
						filter = function(items)
							return vim.tbl_filter(function(item)
								return not string.match(item.basename, [[%__virtual.cs$]])
							end, items)
						end,
					},
				},
			})
		end,
	},
}
