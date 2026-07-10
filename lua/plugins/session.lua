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
			vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,localoptions"

			local function close_alpha_if_open()
				vim.cmd([[
          if &ft == 'alpha'
            Alpha
          endif
        ]])
			end

			local function close_toggleterm_buffers()
				for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
					if vim.bo[bufnr].filetype == "toggleterm" then
						vim.api.nvim_buf_delete(bufnr, { force = true })
					end
				end
			end

			require("auto-session").setup({
				-- Automatically restore the session for the current working directory.
				auto_restore = true,
				suppressed_dirs = { "~/", "/" },
				pre_save_cmds = { close_alpha_if_open, close_toggleterm_buffers, "tabdo NvimTreeClose", "tabdo DiffviewClose" },
			})
		end,
	},
}
