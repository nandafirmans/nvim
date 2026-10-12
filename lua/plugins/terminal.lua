return {
	"akinsho/toggleterm.nvim",
	lazy = false,
	opts = {
		size = 15,
		open_mapping = [[<A-t>]],
		direction = "float",
		close_on_exit = true,
		hide_numbers = true,
		shade_filetypes = {},
		shade_terminals = true,
		shading_factor = 5,
		start_in_insert = true,
		insert_mappings = true,
		persist_size = true,
		shell = (function()
			if jit.os == "Windows" then
				return "pwsh.exe"
			else
				return vim.o.shell
			end
		end)(),
		float_opts = {
			border = "curved",
			width = function()
				return math.floor(vim.o.columns * 1)
			end,
			height = function()
				return math.floor(vim.o.lines * 0.95)
			end,
			winblend = 0,
			highlights = {
				border = "Normal",
				background = "Normal",
			},
		},
	},
	keys = {
		{
			"<leader>gg",
			function()
				vim.cmd.enew()
				vim.cmd.terminal("lazygit")
				local bufnr = vim.api.nvim_get_current_buf()
				vim.api.nvim_create_autocmd("TermClose", {
					buffer = bufnr,
					once = true,
					callback = function()
						if vim.v.event.status == 0 then
							vim.schedule(function()
								if vim.api.nvim_buf_is_valid(bufnr) then
									vim.api.nvim_buf_delete(bufnr, { force = true })
								end
							end)
						end
					end,
				})
				vim.cmd.startinsert()
			end,
			mode = "n",
			desc = "Open LazyGit buffer",
		},
		{ "<leader>yy", "<Cmd>lua _YAZI_TOGGLE()<CR>", mode = "n", desc = "Toggle Yazi File Manager" },
		{ "<leader>tt", "<Cmd>lua _TOP_TOGGLE()<CR>", mode = "n", desc = "Toggle Btop" },
		{ "<leader>ee", "<Cmd>lua _EKPHOS_TOGGLE()<CR>", mode = "n", desc = "Toggle Ekphos" },
	},
	config = function(_, opts)
		local Terminal = require("toggleterm.terminal").Terminal
		local terminal_keymaps = vim.api.nvim_create_augroup("ToggleTermKeymaps", { clear = true })

		local function set_terminal_keymaps()
			local options = { buffer = 0 }
			vim.keymap.set("t", "<C-esc>", [[<C-\><C-n>]], options)
			for _, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
				vim.keymap.set("t", key, [[<C-\><C-n>]] .. key, { buffer = 0, remap = true })
			end
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], options)
		end

		local function create_floating_terminal(command)
			return Terminal:new({
				cmd = command,
				hidden = true,
				direction = "float",
				close_on_exit = true,
				start_in_insert = true,
			})
		end

		local function create_tab_terminal(command)
			return Terminal:new({
				cmd = command,
				hidden = true,
				direction = "tab",
				close_on_exit = true,
				start_in_insert = true,
			})
		end

		local function define_toggle(name, terminal)
			_G[name] = function()
				terminal:toggle()
			end
		end

		require("toggleterm").setup(opts)

		vim.api.nvim_create_autocmd("TermOpen", {
			group = terminal_keymaps,
			pattern = "term://*",
			callback = set_terminal_keymaps,
		})

		define_toggle("_TOP_TOGGLE", create_floating_terminal("btop"))
		define_toggle("_YAZI_TOGGLE", create_floating_terminal("yazi"))
		define_toggle("_EKPHOS_TOGGLE", create_floating_terminal("ekphos"))
	end,
}
