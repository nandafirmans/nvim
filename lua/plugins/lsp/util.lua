local M = {}

local vtsls_project_markers = {
	"tsconfig.json",
	"jsconfig.json",
}

local vtsls_fallback_markers = {
	"package.json",
	".git",
}

M.servers = {
	emmet_ls = {
		filetypes = { "html", "css", "razor" },
	},
	lua_ls = {},
	gopls = {},
	vtsls = {
		vtsls = {
			autoUseWorkspaceTsdk = false,
		},
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
	vtsls = {
		root_dir = function(bufnr, on_dir)
			local name = vim.api.nvim_buf_get_name(bufnr)
			local root = vim.fs.root(name, vtsls_project_markers)

			if not root then
				root = vim.fs.root(name, vtsls_fallback_markers)
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

M.on_attach = function(_, bufnr)
	vim.keymap.set("n", "<A-F>", function()
		require("conform").format({
			bufnr = bufnr,
			async = true,
			-- lsp_format = "fallback",
		})
	end, {
		buffer = bufnr,
		desc = "[F]ormatting file",
	})
	-- Automatically run `:Format` on save
	-- vim.api.nvim_create_autocmd("BufWritePre", {
	--   buffer = bufnr,
	--   command = "Format",
	-- })
end

return M
