return {
	"goolord/alpha-nvim",
	lazy = false,
	event = "VimEnter",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		local function read_fortune()
			if vim.fn.executable("fortune") ~= 1 then
				return ""
			end

			local handle = io.popen("fortune")
			if not handle then
				return ""
			end

			local fortune = handle:read("*a") or ""
			handle:close()
			return fortune
		end

		dashboard.section.header.val = {
			[[                                                    ]],
			[[                                                    ]],
			[[                                                    ]],
			[[                                                    ]],
			[[                                                    ]],
			-- [[            ⣴⣶⣤⡤⠦⣤⣀⣤⠆     ⣈⣭⣿⣶⣿⣦⣼⣆                  ]],
			-- [[             ⠉⠻⢿⣿⠿⣿⣿⣶⣦⠤⠄⡠⢾⣿⣿⡿⠋⠉⠉⠻⣿⣿⡛⣦               ]],
			-- [[                   ⠈⢿⣿⣟⠦ ⣾⣿⣿⣷    ⠻⠿⢿⣿⣧⣄             ]],
			-- [[                    ⣸⣿⣿⢧ ⢻⠻⣿⣿⣷⣄⣀⠄⠢⣀⡀⠈⠙⠿⠄            ]],
			-- [[                   ⢠⣿⣿⣿⠈    ⣻⣿⣿⣿⣿⣿⣿⣿⣛⣳⣤⣀⣀           ]],
			-- [[            ⢠⣧⣶⣥⡤⢄ ⣸⣿⣿⠘  ⢀⣴⣿⣿⡿⠛⣿⣿⣧⠈⢿⠿⠟⠛⠻⠿⠄          ]],
			-- [[           ⣰⣿⣿⠛⠻⣿⣿⡦⢹⣿⣷   ⢊⣿⣿⡏  ⢸⣿⣿⡇ ⢀⣠⣄⣾⠄           ]],
			-- [[          ⣠⣿⠿⠛ ⢀⣿⣿⣷⠘⢿⣿⣦⡀ ⢸⢿⣿⣿⣄ ⣸⣿⣿⡇⣪⣿⡿⠿⣿⣷⡄          ]],
			-- [[          ⠙⠃   ⣼⣿⡟  ⠈⠻⣿⣿⣦⣌⡇⠻⣿⣿⣷⣿⣿⣿ ⣿⣿⡇ ⠛⠻⢷⣄         ]],
			-- [[               ⢻⣿⣿⣄   ⠈⠻⣿⣿⣿⣷⣿⣿⣿⣿⣿⡟ ⠫⢿⣿⡆             ]],
			-- [[                ⠻⣿⣿⣿⣿⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⡟⢀⣀⣤⣾⡿⠃             ]],
			-- [[                                                    ]],
			[[ ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ]],
			[[ ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ]],
			[[ ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ]],
			[[ ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ]],
			[[ ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ]],
			[[ ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ]],
			[[                                                    ]],
		}

		dashboard.section.buttons.val = {
			dashboard.button("e", "󱪝  New File    ", ":enew<CR>"),
			dashboard.button("c", "󰋚  Recent Files ", ":Telescope oldfiles<CR>"),
			dashboard.button("t", "󰊄  Find Text   ", ":Telescope live_grep<CR>"),
			dashboard.button("f", "󰍉  Find File   ", ":Telescope find_files<CR>"),
			dashboard.button("r", "󰙰  Restore session ", ":AutoSession search<CR>"),
			dashboard.button("q", "󰅚  Quit        ", ":qa<CR>"),
		}

		dashboard.section.footer.val = read_fortune()

		dashboard.config.opts.noautocmd = true

		alpha.setup(dashboard.config)
	end,
}
