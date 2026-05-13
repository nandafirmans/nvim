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
				-- Disable automatic restore: a bad saved session can make Nvim appear to
				-- close/crash immediately on startup. Restore manually with <leader>ss.
				auto_restore = false,
				suppressed_dirs = { "~/", "/" },
				pre_save_cmds = { close_alpha_if_open, "tabdo NvimTreeClose", "tabdo DiffviewClose" },
			})
		end,
	},
}
