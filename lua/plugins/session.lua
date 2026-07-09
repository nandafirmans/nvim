return {
	{
		"rmagatti/auto-session",
		lazy = false,
		keys = {
			{
				"<leader>sd",
				"<Cmd>AutoSession deletePicker<CR>",
				mode = "n",
				desc = "[S]ession [D]elete",
			},
			{
				"<leader>ss",
				"<Cmd>AutoSession search<CR>",
				mode = "n",
			},
		},
		config = function()
			vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

			local function close_alpha_if_open()
				vim.cmd([[
          if &ft == 'alpha'
            Alpha
          endif
        ]])
			end

			require("auto-session").setup({
				-- Automatically restore the session for the current working directory.
				auto_restore = true,
				suppressed_dirs = { "~/", "/" },
				pre_save_cmds = { close_alpha_if_open, "tabdo NvimTreeClose", "tabdo DiffviewClose" },
			})
		end,
	},
}
