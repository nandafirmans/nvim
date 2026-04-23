return {
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
		"jlcrochet/vim-razor",
		config = function()
			vim.filetype.add({
				extension = {
					razor = "razor",
					cshtml = "razor",
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

			vim.api.nvim_create_autocmd("BufWritePost", {
				pattern = "*.cs",
				callback = function()
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
}
