return {
	{
		"glepnir/lspsaga.nvim",
		branch = "main",
		lazy = false,
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function(_, opts)
			local function get_reference_client(bufnr)
				for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
					if client:supports_method("textDocument/references") then
						return client
					end
				end
			end

			local function smart_definition()
				local bufnr = vim.api.nvim_get_current_buf()
				local filetype = vim.bo[bufnr].filetype

				if vim.tbl_contains({ "javascript", "javascriptreact", "typescript", "typescriptreact" }, filetype) then
					local ok, vtsls = pcall(require, "vtsls")

					if ok and vtsls.commands and vtsls.commands.goto_source_definition then
						vtsls.commands.goto_source_definition(0, function() end, function()
							vim.cmd("Lspsaga goto_definition")
						end)
						return
					end
				end

				vim.cmd("Lspsaga goto_definition")
			end

			local function fallback_text_references()
				local symbol = vim.fn.expand("<cword>")

				if symbol == nil or symbol == "" then
					return
				end

				require("telescope.builtin").grep_string({
					search = symbol,
					only_sort_text = true,
				})
			end

			local function smart_finder()
				local bufnr = vim.api.nvim_get_current_buf()
				local file_path = vim.api.nvim_buf_get_name(bufnr)
				local reference_client = get_reference_client(bufnr)

				if file_path:match("/node_modules/") or file_path:match("%.d%.ts$") or not reference_client then
					fallback_text_references()
					return
				end

				local params = vim.lsp.util.make_position_params(0, reference_client.offset_encoding)
				params.context = { includeDeclaration = true }

				vim.lsp.buf_request_all(bufnr, "textDocument/references", params, function(results)
					local has_references = false

					for _, result in pairs(results) do
						if result.result and not vim.tbl_isempty(result.result) then
							has_references = true
							break
						end
					end

					if has_references then
						vim.cmd("Lspsaga finder")
						return
					end

					fallback_text_references()
				end)
			end

			require("lspsaga").setup(opts)
			vim.keymap.set("n", "gh", smart_finder, { desc = "Smart LSP Finder" })
			vim.keymap.set("n", "gd", smart_definition, { desc = "Smart Go to Definition" })
		end,
		keys = {
			{ "<leader>ca", "<Cmd>Lspsaga code_action<CR>", mode = { "n", "v" }, desc = "[C]ode [A]ction" },
			{ "<leader>rn", "<Cmd>Lspsaga rename<CR>", mode = "n", desc = "[R]e[N]ame" },
			{ "gp", "<Cmd>Lspsaga peek_definition<CR>", mode = "n", desc = "Peek Definition" },
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
			finder = {
				default = "def+ref",
				methods = {
					tyd = "textDocument/typeDefinition",
				},
			},
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
