-- Generated matugen colors, layered over citruszest for a cleaner base.
local M = {}

local fallback_matugen = {
	bg = "#1b110f",
	surface = "#1b110f",
	surface_container = "#2a1f1d",
	fg = "#f2deda",
	muted = "#ddc0ba",
	primary = "#ffb4a5",
	on_primary = "#5e0d02",
	primary_container = "#e16f59",
	secondary = "#fab6a8",
	tertiary = "#6dd9c4",
	error = "#ffb4ab",
	outline = "#a58b86",
}

local function load_matugen_colors()
	package.loaded["core.walltheme_colors"] = nil
	local ok, colors = pcall(require, "core.walltheme_colors")
	if ok and type(colors) == "table" then
		return vim.tbl_extend("force", fallback_matugen, colors)
	end

	return fallback_matugen
end

local matugen = load_matugen_colors()

local citruszest = {
	bg = "#121212",
	float = "#232323",
	surface = "#232323",
	surface_container = "#383838",
	fg = "#bfbfbf",
	muted = "#767c77",
	selection = "#404040",
	cursor = "#ffd700",
	keyword = "#00bfff",
	function_name = "#00cc7a",
	type = "#ff5454",
	string = "#ffd700",
	constant = "#af74ee",
	identifier = "#bfbfbf",
	statement = "#28c9ff",
	error = "#ff5454",
	warning = "#ffaa54",
	info = "#28c9ff",
	hint = "#33ffff",
	terminal = {
		"#232323",
		"#ff5454",
		"#00cc7a",
		"#ffd700",
		"#00bfff",
		"#af74ee",
		"#00ffff",
		"#bfbfbf",
		"#767c77",
		"#ff1a75",
		"#1affa3",
		"#ffff00",
		"#28c9ff",
		"#af74ee",
		"#33ffff",
		"#f9f9f9",
	},
}

local c = vim.tbl_extend("force", citruszest, {
	-- Keep citruszest as the solid theme base. Use wallpaper colors only as accents.
	primary = matugen.primary,
	on_primary = matugen.on_primary,
	primary_container = matugen.primary_container,
	secondary = matugen.secondary,
	tertiary = matugen.tertiary,
	outline = matugen.outline,
	wallpaper_fg = matugen.fg,
	wallpaper_muted = matugen.muted,
})

local function load_base_theme()
	pcall(function()
		require("citruszest").setup({
			option = {
				transparent = true,
				bold = false,
				italics = true,
			},
		})
	end)

	pcall(vim.cmd.colorscheme, "citruszest")
end

local function set_terminal_colors()
	for index, color in ipairs(c.terminal) do
		vim.g["terminal_color_" .. (index - 1)] = color
	end
end

function M.setup()
	vim.opt.termguicolors = true
	load_base_theme()
	vim.g.colors_name = "matugen-citruszest"

	local hl = vim.api.nvim_set_hl
	hl(0, "Normal", { fg = c.fg, bg = "NONE" })
	hl(0, "NormalNC", { fg = c.fg, bg = "NONE" })
	hl(0, "NormalFloat", { fg = c.fg, bg = c.float })
	hl(0, "FloatBorder", { fg = c.primary, bg = c.float })
	hl(0, "Cursor", { fg = c.bg, bg = c.primary })
	hl(0, "Visual", { bg = c.selection })
	hl(0, "Search", { fg = c.on_primary, bg = c.primary })
	hl(0, "IncSearch", { fg = c.bg, bg = c.tertiary })
	hl(0, "LineNr", { fg = c.muted, bg = "NONE" })
	hl(0, "CursorLineNr", { fg = c.primary, bg = "NONE", bold = true })
	hl(0, "CursorLine", { bg = c.surface_container })
	hl(0, "SignColumn", { bg = "NONE" })
	hl(0, "StatusLine", { fg = c.fg, bg = c.surface_container })
	hl(0, "StatusLineNC", { fg = c.muted, bg = c.surface })
	hl(0, "WinBar", { fg = c.fg, bg = c.surface_container, bold = true })
	hl(0, "WinBarNC", { fg = c.muted, bg = c.surface })
	hl(0, "WinSeparator", { fg = c.outline })
	hl(0, "EndOfBuffer", { fg = c.muted, bg = "NONE" })
	hl(0, "FoldColumn", { fg = c.muted, bg = "NONE" })
	hl(0, "Pmenu", { fg = c.fg, bg = c.float })
	hl(0, "PmenuSel", { fg = c.on_primary, bg = c.primary })

	-- Syntax stays close to citruszest so the wallpaper palette does not wash out code.
	hl(0, "Comment", { fg = c.muted, italic = true })
	hl(0, "String", { fg = c.string })
	hl(0, "Function", { fg = c.function_name })
	hl(0, "Identifier", { fg = c.identifier })
	hl(0, "Statement", { fg = c.statement })
	hl(0, "Keyword", { fg = c.keyword, italic = true })
	hl(0, "Type", { fg = c.type })
	hl(0, "Constant", { fg = c.constant })
	hl(0, "Error", { fg = c.error })
	hl(0, "DiagnosticError", { fg = c.error })
	hl(0, "DiagnosticWarn", { fg = c.warning })
	hl(0, "DiagnosticInfo", { fg = c.info })
	hl(0, "DiagnosticHint", { fg = c.hint })

	-- Lualine/winbar uses wallpaper accents over citruszest surfaces for contrast.
	local lualine_groups = {
		lualine_a_normal = { fg = c.on_primary, bg = c.primary, bold = true },
		lualine_b_normal = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_c_normal = { fg = c.fg, bg = c.surface, bold = true },
		lualine_x_normal = { fg = c.fg, bg = c.surface, bold = true },
		lualine_y_normal = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_z_normal = { fg = c.on_primary, bg = c.primary, bold = true },
		lualine_a_insert = { fg = c.bg, bg = c.secondary, bold = true },
		lualine_b_insert = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_c_insert = { fg = c.fg, bg = c.surface, bold = true },
		lualine_x_insert = { fg = c.fg, bg = c.surface, bold = true },
		lualine_y_insert = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_z_insert = { fg = c.bg, bg = c.secondary, bold = true },
		lualine_a_visual = { fg = c.bg, bg = c.tertiary, bold = true },
		lualine_b_visual = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_c_visual = { fg = c.fg, bg = c.surface, bold = true },
		lualine_x_visual = { fg = c.fg, bg = c.surface, bold = true },
		lualine_y_visual = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_z_visual = { fg = c.bg, bg = c.tertiary, bold = true },
		lualine_a_command = { fg = c.on_primary, bg = c.primary, bold = true },
		lualine_b_command = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_c_command = { fg = c.fg, bg = c.surface, bold = true },
		lualine_x_command = { fg = c.fg, bg = c.surface, bold = true },
		lualine_y_command = { fg = c.fg, bg = c.surface_container, bold = true },
		lualine_z_command = { fg = c.on_primary, bg = c.primary, bold = true },
		lualine_a_inactive = { fg = c.muted, bg = c.surface_container },
		lualine_b_inactive = { fg = c.muted, bg = c.surface },
		lualine_c_inactive = { fg = c.muted, bg = c.surface },
		lualine_x_inactive = { fg = c.muted, bg = c.surface },
		lualine_y_inactive = { fg = c.muted, bg = c.surface },
		lualine_z_inactive = { fg = c.muted, bg = c.surface_container },
	}

	for group, spec in pairs(lualine_groups) do
		hl(0, group, spec)
	end

	set_terminal_colors()
end

return M
