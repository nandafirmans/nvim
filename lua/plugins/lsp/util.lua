local M = {}

M.servers = {
	emmet_ls = {
		filetypes = { "html", "css", "razor" },
	},
	lua_ls = {},
	gopls = {},
	ts_ls = {},
	sqls = {},
	cssls = {},
	html = {
		filetypes = { "html", "razor" },
	},
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

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
