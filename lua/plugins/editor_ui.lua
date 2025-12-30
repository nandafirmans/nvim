return {
	{
		"folke/noice.nvim",
		dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
		opts = {
			messages = {
				enabled = true,
			},
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},
			routes = {
				{
					filter = {
						event = "msg_show",
						kind = "",
						any = {
							{ find = "nil" },
							{ find = "written" },
							{ find = "bufdelete" },
							{ find = "SERVER_REQUEST_HANDLER_ERROR" },
							{ find = "CursorMoved" },
							{ find = "ModeChanged" },
						},
					},
					opts = { skip = true },
				},
			},
			presets = {
				command_palette = true,
				long_message_to_split = true,
			},
		},
		config = function(_, opts)
			local notify = require("notify")
			notify.setup({
				render = "wrapped-compact",
				stages = "static",
				timeout = 3000,
			})

			require("noice").setup(opts)
		end,
	},

	-- File Explorer
	{
		"nvim-tree/nvim-tree.lua",
		-- tag = "nightly", -- optional, updated every week. (see issue #1193)
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = {
			{ "<leader>n", "<Cmd>NvimTreeToggle<CR>", mode = "n" },
		},
		config = function()
			local function open_win_config_func()
				local scr_w = vim.opt.columns:get()
				local scr_h = vim.opt.lines:get()
				local tree_w = 80
				local tree_h = math.floor(tree_w * scr_h / scr_w) + 20
				return {
					border = "rounded",
					relative = "editor",
					width = tree_w,
					height = tree_h,
					col = (scr_w - tree_w) / 2,
					row = (scr_h - tree_h) / 2,
				}
			end

			require("nvim-tree").setup({
				update_focused_file = {
					enable = true,
				},
				view = {
					float = {
						enable = true,
						open_win_config = open_win_config_func,
					},
					side = "right",
					width = 50,
				},
				actions = {
					open_file = {
						resize_window = true,
						quit_on_open = true,
					},
				},
			})
		end,
	},

	-- Tabs & Buffers
	{
		"akinsho/bufferline.nvim",
		branch = "main",
		lazy = false,
		dependencies = "nvim-tree/nvim-web-devicons",
		keys = {
			{ "<A-.>", "<Cmd>BufferLineCycleNext<CR>", mode = "n", desc = "BufferLine Cycle Next" },
			{ "<A-,>", "<Cmd>BufferLineCyclePrev<CR>", mode = "n", desc = "BufferLine Cycle Prev" },
			{ "<C-.>", "<Cmd>BufferLineMoveNext<CR>", mode = "n", desc = "BufferLine Move Next" },
			{ "<C-,>", "<Cmd>BufferLineMovePrev<CR>", mode = "n", desc = "BufferLine Move Prev" },
			{ "<A-p>p", "<Cmd>BufferLinePick<CR>", mode = "n", desc = "BufferLine Pick" },
			{ "<A-p>w", "<Cmd>BufferLinePickClose<CR>", mode = "n", desc = "BufferLine Pick Close" },
			{ "<A-s>e", "<Cmd>BufferLineSortByTabs<CR>", mode = "n", desc = "BufferLine Sort By Tabs" },
			{ "<A-s>e", "<Cmd>BufferLineSortByExtension<CR>", mode = "n", desc = "BufferLine Sort By Extension" },
			{ "<A-s>d", "<Cmd>BufferLineSortByDirectory<CR>", mode = "n", desc = "BufferLine Sort By Directory" },
			{
				"<A-s>r",
				"<Cmd>BufferLineSortByRelativeDirectory<CR>",
				mode = "n",
				desc = "BufferLine Sort By Relative Directory",
			},
		},
		opts = {
			options = {
				diagnostics = "nvim_lsp",
				truncate_names = false,
				indicator = {
					style = "none",
				},
				hover = {
					enabled = true,
					delay = 100,
					reveal = { "close" },
				},
				-- separator_style = 'slant',
				offsets = {
					{
						filetype = "NvimTree",
						text = "File Explorer",
						text_align = "center",
						separator = true,
					},
				},
			},
		},
		config = function(_, opts)
			require("bufferline").setup(opts)
		end,
	},

	{
		"nvim-pack/nvim-spectre",
		lazy = false,
		dependencies = "nvim-lua/plenary.nvim",
		keys = {
			{
				"<leader>F",
				'<CMD>lua require("spectre").toggle()<CR>',
				mode = "n",
				desc = "Toggle Spectre",
			},
			{
				"<leader>F",
				'<ESC><CMD>lua require("spectre").open_visual()<CR>',
				mode = "v",
				desc = "Search Selected Text",
			},
			{
				"<leader>FF",
				'<CMD>lua require("spectre").open_file_search({select_word=true})<CR>',
				mode = "n",
				desc = "Search on current file",
			},
		},
		config = function()
			require("spectre").setup({
				is_block_ui_break = true,
			})
		end,
	},

	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		config = function()
			local highlight = {
				"RainbowRed",
				"RainbowYellow",
				"RainbowBlue",
				"RainbowOrange",
				"RainbowGreen",
				"RainbowViolet",
				"RainbowCyan",
			}
			local hooks = require("ibl.hooks")
			-- create the highlight groups in the highlight setup hook, so they are reset
			-- every time the colorscheme changes
			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
				vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
				vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
				vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
				vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
				vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
				vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
			end)

			-- highlight = {
			-- 	"CursorColumn",
			-- 	"Whitespace",
			-- }

			require("ibl").setup({
				indent = {
					-- 	highlight = highlight,
					char = "│",
				},
				-- whitespace = {
				-- 	highlight = highlight,
				-- 	remove_blankline_trail = false,
				-- },
				scope = {
					highlight = highlight,
					show_start = false,
					show_end = false,
					-- enabled = false
				},
			})

			hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
		end,
	},

	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")

			harpoon:setup()

			vim.keymap.set("n", "<A-a>", function()
				harpoon:list():add()
			end)
			vim.keymap.set("n", "<A-e>", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end)

			vim.keymap.set("n", "<leader>1", function()
				harpoon:list():select(1)
			end)
			vim.keymap.set("n", "<leader>2", function()
				harpoon:list():select(2)
			end)
			vim.keymap.set("n", "<leader>3", function()
				harpoon:list():select(3)
			end)
			vim.keymap.set("n", "<leader>4", function()
				harpoon:list():select(4)
			end)
			vim.keymap.set("n", "<leader>5", function()
				harpoon:list():select(5)
			end)
			vim.keymap.set("n", "<leader>6", function()
				harpoon:list():select(6)
			end)
			vim.keymap.set("n", "<leader>7", function()
				harpoon:list():select(7)
			end)
			vim.keymap.set("n", "<leader>8", function()
				harpoon:list():select(8)
			end)
			vim.keymap.set("n", "<leader>9", function()
				harpoon:list():select(9)
			end)

			vim.keymap.set("n", "<leader>h", function()
				harpoon:list():prev()
			end, { desc = "Harpoon: Previous", noremap = true })
			vim.keymap.set("n", "<leader>l", function()
				harpoon:list():next()
			end, { desc = "Harpoon: Next", noremap = true })
		end,
	},
	{
		"nvim-mini/mini.animate",
		version = "*",
		config = function()
			local animate = require("mini.animate")

			-- don't use animate when scrolling with the mouse
			local mouse_scrolled = false
			for _, scroll in ipairs({ "Up", "Down" }) do
				local key = "<ScrollWheel" .. scroll .. ">"
				vim.keymap.set({ "", "i" }, key, function()
					mouse_scrolled = true
					return key
				end, { expr = true })
			end

			animate.setup({
				cursor = {
					enable = false,
				},
				resize = {
					timing = animate.gen_timing.linear({ duration = 50, unit = "total" }),
				},
				scroll = {
					timing = animate.gen_timing.linear({ duration = 150, unit = "total" }),
					subscroll = animate.gen_subscroll.equal({
						predicate = function(total_scroll)
							if mouse_scrolled then
								mouse_scrolled = false
								return false
							end
							return total_scroll > 1
						end,
					}),
				},
			})
		end,
	},
	-- {
	-- 	"sphamba/smear-cursor.nvim",
	-- 	opts = {
	-- 		cursor_color = "#ff4000",
	-- 		particles_enabled = true,
	-- 		stiffness = 0.5,
	-- 		trailing_stiffness = 0.2,
	-- 		trailing_exponent = 5,
	-- 		damping = 0.6,
	-- 		gradient_exponent = 0,
	-- 		gamma = 1,
	-- 		never_draw_over_target = true, -- if you want to actually see under the cursor
	-- 		hide_target_hack = true, -- same
	-- 		particle_spread = 1,
	-- 		particles_per_second = 500,
	-- 		particles_per_length = 50,
	-- 		particle_max_lifetime = 800,
	-- 		particle_max_initial_velocity = 20,
	-- 		particle_velocity_from_cursor = 0.5,
	-- 		particle_damping = 0.15,
	-- 		particle_gravity = -50,
	-- 		min_distance_emit_particles = 0,
	-- 		legacy_computing_symbols_support = true,
	-- 	},
	-- },
}
