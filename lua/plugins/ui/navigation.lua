return {
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")
			local telescope_config = require("telescope.config").values

			local function toggle_telescope(harpoon_files)
				local file_paths = {}

				for _, item in ipairs(harpoon_files.items) do
					table.insert(file_paths, item.value)
				end

				require("telescope.pickers")
					.new({}, {
						prompt_title = "Harpoon",
						finder = require("telescope.finders").new_table({
							results = file_paths,
						}),
						previewer = telescope_config.file_previewer({}),
						sorter = telescope_config.generic_sorter({}),
					})
					:find()
			end

			harpoon:setup({})

			vim.keymap.set("n", "<A-E>", function()
				toggle_telescope(harpoon:list())
			end, { desc = "Open harpoon window" })

			vim.keymap.set("n", "<A-a>", function()
				harpoon:list():add()
			end, { desc = "Harpoon Add File" })

			vim.keymap.set("n", "<A-e>", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end, { desc = "Harpoon Toggle Menu" })

			for index = 1, 9 do
				vim.keymap.set("n", "<leader>" .. index, function()
					harpoon:list():select(index)
				end, { desc = "Harpoon Select " .. index })
			end

			vim.keymap.set("n", "<leader>h", function()
				harpoon:list():prev()
			end, { desc = "Harpoon Previous", noremap = true })

			vim.keymap.set("n", "<leader>l", function()
				harpoon:list():next()
			end, { desc = "Harpoon Next", noremap = true })
		end,
	},
}
