return {
	{
		"neovim/nvim-lspconfig",
		lazy = false,
	},
	{
		"onsails/lspkind.nvim",
	},
	{
		"mason-org/mason-lspconfig.nvim",
		version = "^1.0.0",
	},
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
			local lsp_util = require("plugins.lsp.util")
			local mason_lspconfig = require("mason-lspconfig")

			require("mason").setup({
				registries = {
					"github:mason-org/mason-registry",
					"github:Crashdummyy/mason-registry",
				},
			})

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
}
