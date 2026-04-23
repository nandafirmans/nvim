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
				vim.lsp.buf.definition()
			end)
			return
		end
	end

	vim.lsp.buf.definition()
end

local function fallback_text_references()
	local symbol = vim.fn.expand("<cword>")

	if symbol == nil or symbol == "" then
		return
	end

	Snacks.picker.grep_word()
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
			Snacks.picker.lsp_references()
			return
		end

		fallback_text_references()
	end)
end

return {
	{
		"neovim/nvim-lspconfig",
		keys = {
			{ "gh", smart_finder, mode = "n", desc = "Smart LSP Finder" },
			{ "gd", smart_definition, mode = "n", desc = "Smart Go to Definition" },
			{
				"<leader>ca",
				function()
					vim.lsp.buf.code_action()
				end,
				mode = { "n", "v" },
				desc = "[C]ode [A]ction",
			},
			{
				"gp",
				function()
					require("goto-preview").goto_preview_definition()
				end,
				mode = "n",
				desc = "Peek Definition",
			},
			{
				"<leader>rn",
				function()
					local current_name = vim.fn.expand("<cword>")

					vim.ui.input({
						prompt = "Rename to: ",
						default = current_name,
					}, function(input)
						if not input or input == "" or input == current_name then
							return
						end

						vim.lsp.buf.rename(input)
					end)
				end,
				mode = "n",
				desc = "[R]e[N]ame",
			},
			{
				"<leader>sl",
				function()
					vim.diagnostic.open_float()
				end,
				mode = "n",
				desc = "Show Line Diagnostics",
			},
			{
				"<leader>sc",
				function()
					vim.diagnostic.open_float()
				end,
				mode = "n",
				desc = "Show Cursor Diagnostics",
			},
			{
				"<leader>sb",
				function()
					Snacks.picker.diagnostics_buffer()
				end,
				mode = "n",
				desc = "Show Buffer Diagnostics",
			},
			{
				"[e",
				function()
					vim.diagnostic.jump({ count = -1, float = true })
				end,
				mode = "n",
				desc = "Previous Diagnostic",
			},
			{
				"]e",
				function()
					vim.diagnostic.jump({ count = 1, float = true })
				end,
				mode = "n",
				desc = "Next Diagnostic",
			},
			{
				"[E",
				function()
					vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR, float = true })
				end,
				mode = "n",
				desc = "Previous Error",
			},
			{
				"]E",
				function()
					vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR, float = true })
				end,
				mode = "n",
				desc = "Next Error",
			},
			{
				"<Leader>ci",
				function()
					Snacks.picker.lsp_incoming_calls()
				end,
				mode = "n",
				desc = "Incoming Calls",
			},
			{
				"<Leader>co",
				function()
					Snacks.picker.lsp_outgoing_calls()
				end,
				mode = "n",
				desc = "Outgoing Calls",
			},
			{
				"K",
				function()
					vim.lsp.buf.hover()
				end,
				mode = "n",
				desc = "Hover Documentation",
			},
		},
	},
	{
		"rmagatti/goto-preview",
		dependencies = {
			"rmagatti/logger.nvim",
		},
		event = "BufEnter",
		opts = {
			default_mappings = false,
			references = {
				provider = "snacks",
			},
			focus_on_open = true,
			dismiss_on_move = false,
			stack_floating_preview_windows = true,
		},
		config = function(_, opts)
			require("goto-preview").setup(opts)
		end,
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
