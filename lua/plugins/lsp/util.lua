local M = {}

M.servers = {
	emmet_ls = {},
	lua_ls = {},
	gopls = {},
	ts_ls = {},
	sqls = {},
	cssls = {},
	html = {},
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

M.on_attach = function(_, bufnr)
	local nmap = function(keys, func, desc)
		if desc then
			desc = "LSP: " .. desc
		end

		vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
	end

	-- Format command
	nmap("<A-F>", ":Format<CR>", "[F]ormatting file")

	vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
		require("conform").format({ bufnr = bufnr, async = true })
		-- vim.lsp.buf.format()
	end, { desc = "Format current buffer with LSP" })

	-- Automatically run `:Format` on save
	-- vim.api.nvim_create_autocmd("BufWritePre", {
	--   buffer = bufnr,
	--   command = "Format",
	-- })
end

return M
