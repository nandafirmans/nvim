local M = {}

local ts_project_markers = {
	"tsconfig.json",
	"jsconfig.json",
}

local ts_fallback_markers = {
	"package.json",
	".git",
}

M.servers = {
	emmet_ls = {
		filetypes = { "html", "css", "razor" },
	},
	lua_ls = {},
	gopls = {},
	ts_ls = {
		typescript = {
			updateImportsOnFileMove = {
				enabled = "always",
			},
			suggest = {
				completeFunctionCalls = true,
			},
		},
		javascript = {
			updateImportsOnFileMove = {
				enabled = "always",
			},
			suggest = {
				completeFunctionCalls = true,
			},
		},
	},
	sqls = {},
	cssls = {},
	html = {
		filetypes = { "html", "razor" },
	},
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

M.configs = {
	ts_ls = {
		root_dir = function(bufnr, on_dir)
			local name = vim.api.nvim_buf_get_name(bufnr)
			local root = vim.fs.root(name, ts_project_markers)

			if not root then
				root = vim.fs.root(name, ts_fallback_markers)
			end

			if not root and name ~= "" then
				root = vim.fs.dirname(name)
			end

			if root then
				on_dir(root)
			end
		end,
		single_file_support = true,
	},
}

M.on_attach = function() end

return M
