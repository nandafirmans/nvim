return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")
			local js_languages = {
				"typescript",
				"javascript",
				"typescriptreact",
				"javascriptreact",
			}

			local function refresh_dap_ui(action)
				return function()
					dapui[action]()
				end
			end

			local function set_dap_keymaps()
				vim.keymap.set("n", "<leader>bt", dap.toggle_breakpoint, { desc = "DAP Toggle Breakpoint" })
				vim.keymap.set("n", "<leader>bc", dap.continue, { desc = "DAP Continue" })
				vim.keymap.set("n", "<leader>bi", dap.step_into, { desc = "DAP Step Into" })
				vim.keymap.set("n", "<leader>bo", dap.step_over, { desc = "DAP Step Over" })
				vim.keymap.set("n", "<leader>bq", dap.terminate, { desc = "DAP Terminate" })
				vim.keymap.set("n", "<A-B>", dapui.open, { desc = "DAP UI Open" })
				vim.keymap.set("n", "<A-b>", dapui.close, { desc = "DAP UI Close" })
			end

			dapui.setup()

			dap.listeners.before.attach.dapui_config = refresh_dap_ui("open")
			dap.listeners.before.launch.dapui_config = refresh_dap_ui("open")
			dap.listeners.before.event_terminated.dapui_config = refresh_dap_ui("close")
			dap.listeners.before.event_exited.dapui_config = refresh_dap_ui("close")

			set_dap_keymaps()

			dap.adapters.chrome = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = "node",
					args = {
						require("mason-registry").get_package("js-debug-adapter"):get_install_path()
							.. "/js-debug/src/dapDebugServer.js",
						"${port}",
					},
				},
			}

			for _, lang in ipairs(js_languages) do
				dap.configurations[lang] = dap.configurations[lang] or {}
				table.insert(dap.configurations[lang], {
					type = "chrome",
					request = "launch",
					name = "Launch Chrome",
					url = "http://localhost:3000",
					webRoot = vim.fn.getcwd(),
					sourceMaps = true,
				})
				table.insert(dap.configurations[lang], {
					type = "chrome",
					request = "attach",
					program = "${file}",
					cwd = vim.fn.getcwd(),
					sourceMaps = true,
					protocol = "inspector",
					port = 9222,
					webRoot = "${workspaceFolder}",
				})
			end
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
	},
	{
		"nicholasmata/nvim-dap-cs",
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			require("dap-cs").setup()
		end,
	},
	{
		"Cliffback/netcoredbg-macOS-arm64.nvim",
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			if vim.fn.has("mac") == 0 then
				return
			end

			require("netcoredbg-macOS-arm64").setup(require("dap"))
		end,
	},
}
