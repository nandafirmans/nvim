return {
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
		config = function()
			require("conform").setup({
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
			})
		end,
	},
}
