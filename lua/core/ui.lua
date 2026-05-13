local M = {}

local function load_walltheme()
	local path = vim.fn.stdpath("config") .. "/lua/core/walltheme.lua"
	if vim.uv.fs_stat(path) == nil then
		vim.cmd.colorscheme("bluloco")
		return
	end

	package.loaded["core.walltheme"] = nil
	local ok, theme = pcall(require, "core.walltheme")
	if ok and type(theme.setup) == "function" then
		theme.setup()
		pcall(function()
			require("lualine").refresh({ place = { "statusline", "tabline", "winbar" } })
		end)
	else
		vim.cmd.colorscheme("bluloco")
	end
end

function M.reload_walltheme()
	load_walltheme()
end

function M.setup()
	load_walltheme()

	vim.api.nvim_create_user_command("WallpaperThemeReload", function()
		load_walltheme()
	end, {})
end

return M
