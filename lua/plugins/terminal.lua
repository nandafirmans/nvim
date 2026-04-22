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
			winblend = 0,
			highlights = {
				border = "Normal",
				background = "Normal",
			},
		},
	},
	keys = {
		{ "<leader>gg", "<Cmd>lua _LAZYGIT_TOGGLE()<CR>", mode = "n", desc = "Toggle LazyGit" },
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
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], options)
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], options)
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], options)
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], options)
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

		define_toggle("_LAZYGIT_TOGGLE", create_floating_terminal("lazygit"))
		define_toggle("_TOP_TOGGLE", create_floating_terminal("btop"))
		define_toggle("_YAZI_TOGGLE", create_floating_terminal("yazi"))
		define_toggle("_EKPHOS_TOGGLE", create_floating_terminal("ekphos"))
	end,
}
