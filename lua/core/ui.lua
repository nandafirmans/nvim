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
		-- Lets lua/agents/theme.lua save this as "wallpaper", not its base theme.
		vim.g.walltheme_loading = true
		local loaded = pcall(theme.setup)
		vim.g.walltheme_loading = false
		vim.g.walltheme_active = loaded
		pcall(function()
			require("plugins.lualine.util").hide_lualine_buffers()
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
