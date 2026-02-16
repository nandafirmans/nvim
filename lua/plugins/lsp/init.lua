return {
	{
		"neovim/nvim-lspconfig",
		lazy = false,
	},
	{ "onsails/lspkind.nvim" },
	{ "mason-org/mason-lspconfig.nvim", version = "^1.0.0" },
	-- {
	-- 	"nvim-java/nvim-java",
	-- 	config = function()
	-- 		local lsp_util = require("plugins.lsp.util")
	-- 		require("java").setup()
	-- 		vim.lsp.config("jdtls", {
	-- 			capabilities = lsp_util.capabilities,
	-- 		})
	-- 	end,
	-- },
	{
		"mason-org/mason.nvim",
		version = "^1.0.0",
		dependencies = {
			"mason-org/mason-lspconfig.nvim",
			"pmizio/typescript-tools.nvim",
			"nvim-lua/plenary.nvim",
			"neovim/nvim-lspconfig",
		},
		config = function()
			require("mason").setup({
				registries = {
					"github:mason-org/mason-registry",
					"github:Crashdummyy/mason-registry",
				},
			})
			local lsp_util = require("plugins.lsp.util")
			local mason_lspconfig = require("mason-lspconfig")

			mason_lspconfig.setup({
				ensure_installed = vim.tbl_keys(lsp_util.servers),
				automatic_installation = true,
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if not client then
						return
					end

					if client.name == "ts_ls" then
						client.server_capabilities.documentFormattingProvider = false
					end

					lsp_util.on_attach(client, args.buf)
				end,
			})

			mason_lspconfig.setup_handlers({
				function(server_name)
					vim.lsp.config(server_name, {
						capabilities = lsp_util.capabilities,
						settings = lsp_util.servers[server_name],
					})
					vim.lsp.enable(server_name)
				end,
			})
		end,
	},
	{
		"mfussenegger/nvim-lint",
		config = function()
			require("lint").linters_by_ft = {
				javascript = { "eslint_d" },
				typescript = { "eslint_d" },
				javascriptreact = { "eslint_d" },
				typescriptreact = { "eslint_d" },
			}
			vim.api.nvim_create_autocmd("BufWritePost", {
				pattern = { "*.js", "*.jsx", "*.ts", "*.tsx" },
				callback = function()
					require("lint").try_lint()
				end,
			})
		end,
	},
	{
		"stevearc/conform.nvim",
		opts = {
			lang_to_ext = {
				c_sharp = "cs",
			},
			formatters_by_ft = {
				lua = { "stylua" },
				javascript = { "prettierd", "eslint_d", stop_after_first = true },
				javascriptreact = { "prettierd", "eslint_d", stop_after_first = true },
				typescript = { "prettierd", "eslint_d", stop_after_first = true },
				typescriptreact = { "prettierd", "eslint_d", stop_after_first = true },
				css = { "prettierd", "prettier", stop_after_first = true },
				less = { "prettierd", "prettier", stop_after_first = true },
				scss = { "prettierd", "prettier", stop_after_first = true },
				html = { "prettierd", "prettier", stop_after_first = true },
				json = { "prettierd", "prettier", stop_after_first = true },
				markdown = { "prettierd", "prettier", stop_after_first = true },
				sql = { "sqlfluff" },
				go = { "gofmt", "goimports", "goimports_reviser", "golines" },
				cshtml = { "superhtml" },
				razor = { "superhtml" },
				cs = { "csharpier_extend" },
				csproj = { "csharpier_extend" },
				xml = { "xmllint" },
			},
			formatters = {
				csharpier_extend = {
					command = "csharpier",
					args = {
						"format",
						"--write-stdout",
					},
					to_stdin = true,
				},
			},
			format_on_save = {
				timeout_ms = 500,
				lsp_format = "first",
				filter = function(client)
					return client.name == "eslint"
				end,
			},
		},
	},
	{
		"folke/neodev.nvim",
		config = function()
			require("neodev").setup()
		end,
	},
	{
		"antosha417/nvim-lsp-file-operations",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-tree.lua",
		},
		config = function()
			require("lsp-file-operations").setup()
		end,
	},
	{
		"akinsho/flutter-tools.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local lsp_util = require("plugins.lsp.util")
			require("flutter-tools").setup({
				lsp = {
					capabilities = lsp_util.capabilities,
					on_attach = lsp_util.on_attach,
				},
			})
		end,
	},
	{
		"glepnir/lspsaga.nvim",
		lazy = false,
		branch = "main",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"nvim-treesitter/nvim-treesitter",
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
		keys = {
			{
				"gh",
				"<cmd>Lspsaga finder<CR>",
				mode = "n",
			},
			{
				"<leader>ca",
				"<cmd>Lspsaga code_action<CR>",
				mode = { "n", "v" },
				desc = "[C]ode [A]ction",
			},
			{
				"<leader>rn",
				"<cmd>Lspsaga rename<CR>",
				mode = "n",
				desc = "[R]e[N]ame",
			},
			{
				"gp",
				"<cmd>Lspsaga peek_definition<CR>",
				mode = "n",
				desc = "Peek Definition",
			},
			{
				"gd",
				"<cmd>Lspsaga goto_definition<CR>",
				mode = "n",
				desc = "[G]o to [D]efinition",
			},
			{
				"<leader>sl",
				"<cmd>Lspsaga show_line_diagnostics<CR>",
				mode = "n",
			},
			{
				"<leader>sc",
				"<cmd>Lspsaga show_cursor_diagnostics<CR>",
				mode = "n",
			},
			{
				"<leader>sb",
				"<cmd>Lspsaga show_buf_diagnostics<CR>",
				mode = "n",
			},
			{
				"[e",
				"<cmd>Lspsaga diagnostic_jump_prev<CR>",
				mode = "n",
			},
			{
				"]e",
				"<cmd>Lspsaga diagnostic_jump_next<CR>",
				mode = "n",
			},
			{
				"[E",
				function()
					require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR })
				end,
				mode = "n",
			},
			{
				"]E",
				function()
					require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR })
				end,
				mode = "n",
			},
			-- {
			-- 	"<leader>o",
			-- 	"<cmd>Lspsaga outline<CR>",
			-- 	mode = "n",
			-- },
			{
				"<Leader>ci",
				"<cmd>Lspsaga incoming_calls<CR>",
				mode = "n",
			},
			{
				"<Leader>co",
				"<cmd>Lspsaga outgoing_calls<CR>",
				mode = "n",
			},
			{
				"K",
				"<cmd>Lspsaga hover_doc<CR>",
				mode = "n",
			},
			{
				"<A-T>",
				"<cmd>Lspsaga term_toggle<CR>",
				mode = { "n", "t" },
			},
		},
	},
	{
		"jlcrochet/vim-razor",
		config = function()
			vim.cmd([[
        au BufRead,BufNewFile *.cshtml set filetype=razor
      ]])

			vim.filetype.add({
				extension = {
					razor = "html",
					cshtml = "html",
				},
			})
		end,
	},

	{
		"seblyng/roslyn.nvim",
		dependencies = { "j-hui/fidget.nvim" },
		config = function()
			local handles = {}

			vim.api.nvim_create_autocmd("User", {
				pattern = "RoslynRestoreProgress",
				callback = function(ev)
					local token = ev.data.params[1]
					local handle = handles[token]
					if handle then
						handle:report({
							title = ev.data.params[2].state,
							message = ev.data.params[2].message,
						})
					else
						handles[token] = require("fidget.progress").handle.create({
							title = ev.data.params[2].state,
							message = ev.data.params[2].message,
							lsp_client = {
								name = "roslyn",
							},
						})
					end
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				pattern = "RoslynRestoreResult",
				callback = function(ev)
					local handle = handles[ev.data.token]
					handles[ev.data.token] = nil

					if handle then
						handle.message = ev.data.err and ev.data.err.message or "Restore completed"
						handle:finish()
					end
				end,
			})

			vim.api.nvim_create_autocmd({ "BufWritePost" }, {
				pattern = "*.cs",
				callback = function(args)
					local clients = vim.lsp.get_clients({ name = "roslyn" })
					if not clients or #clients == 0 then
						return
					end

					local client = clients[1]
					local buffers = vim.lsp.get_buffers_by_client_id(client.id)
					for _, buf in ipairs(buffers) do
						local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
						client:request("textDocument/diagnostic", params, nil, buf)
					end
				end,
			})
		end,
	},
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
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
		keys = {
			{
				"<leader>xx",
				"<cmd>Trouble diagnostics toggle<cr>",
				desc = "Diagnostics (Trouble)",
			},
			{
				"<leader>xX",
				"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
				desc = "Buffer Diagnostics (Trouble)",
			},
			{
				"<leader>cs",
				"<cmd>Trouble symbols toggle focus=false<cr>",
				desc = "Symbols (Trouble)",
			},
			{
				"<leader>cl",
				"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
				desc = "LSP Definitions / references / ... (Trouble)",
			},
			{
				"<leader>xL",
				"<cmd>Trouble loclist toggle<cr>",
				desc = "Location List (Trouble)",
			},
			{
				"<leader>xQ",
				"<cmd>Trouble qflist toggle<cr>",
				desc = "Quickfix List (Trouble)",
			},
		},
	},
}
