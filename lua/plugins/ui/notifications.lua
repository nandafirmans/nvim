return {
	{
		"folke/noice.nvim",
		dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
		opts = {
			messages = {
				enabled = true,
			},
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},
			routes = {
				{
					filter = {
						event = "msg_show",
						kind = "",
						any = {
							{ find = "nil" },
							{ find = "written" },
							{ find = "bufdelete" },
							{ find = "SERVER_REQUEST_HANDLER_ERROR" },
							{ find = "CursorMoved" },
							{ find = "ModeChanged" },
						},
					},
					opts = { skip = true },
				},
			},
			presets = {
				command_palette = true,
				long_message_to_split = true,
			},
		},
		config = function(_, opts)
			local notify = require("notify")

			notify.setup({
				render = "wrapped-compact",
				stages = "static",
				timeout = 3000,
			})

			require("noice").setup(opts)
		end,
	},
}
