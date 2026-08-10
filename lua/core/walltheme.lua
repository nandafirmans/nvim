-- Generated matugen colors, layered over tokyonight for a cleaner base.
local M = {}

local fallback_matugen = {
	bg = "#1a1b26",
	surface = "#1a1b26",
	surface_container = "#24283b",
	fg = "#c0caf5",
	muted = "#565f89",
	primary = "#7aa2f7",
	on_primary = "#15161e",
	primary_container = "#2e3c64",
	secondary = "#bb9af7",
	tertiary = "#7dcfff",
	error = "#f7768e",
	outline = "#414868",
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

local tokyonight = {
	bg = "#1a1b26",
	float = "#16161e",
	surface = "#1f2335",
	surface_container = "#24283b",
	fg = "#c0caf5",
	muted = "#565f89",
	selection = "#2e3c64",
	cursor = "#c0caf5",
	keyword = "#bb9af7",
	function_name = "#7aa2f7",
	type = "#2ac3de",
	string = "#9ece6a",
	constant = "#ff9e64",
	identifier = "#c0caf5",
	statement = "#bb9af7",
	error = "#f7768e",
	warning = "#e0af68",
	info = "#7dcfff",
	hint = "#1abc9c",
	terminal = {
		"#15161e",
		"#f7768e",
		"#9ece6a",
		"#e0af68",
		"#7aa2f7",
		"#bb9af7",
		"#7dcfff",
		"#a9b1d6",
		"#414868",
		"#f7768e",
		"#9ece6a",
		"#e0af68",
		"#7aa2f7",
		"#bb9af7",
		"#7dcfff",
		"#c0caf5",
	},
}

local c = vim.tbl_extend("force", tokyonight, {
	-- Keep tokyonight as the solid theme base. Use wallpaper colors only as accents.
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
		require("tokyonight").setup({
			style = "night",
			transparent = true,
			styles = {
				sidebars = "transparent",
				floats = "transparent",
			},
		})
	end)

	pcall(vim.cmd.colorscheme, "tokyonight-night")
end

local function set_terminal_colors()
	for index, color in ipairs(c.terminal) do
		vim.g["terminal_color_" .. (index - 1)] = color
	end
end

function M.lualine_theme()
	local function section(fg, bg)
		return { fg = fg, bg = bg, gui = "bold" }
	end

	return {
		normal = {
			a = section(c.on_primary, c.primary),
			b = section(c.fg, c.surface_container),
			c = section(c.fg, c.surface),
			x = section(c.fg, c.surface),
			y = section(c.fg, c.surface_container),
			z = section(c.on_primary, c.primary),
		},
		insert = {
			a = section(c.bg, c.secondary),
			b = section(c.fg, c.surface_container),
			c = section(c.fg, c.surface),
			x = section(c.fg, c.surface),
			y = section(c.fg, c.surface_container),
			z = section(c.bg, c.secondary),
		},
		visual = {
			a = section(c.bg, c.tertiary),
			b = section(c.fg, c.surface_container),
			c = section(c.fg, c.surface),
			x = section(c.fg, c.surface),
			y = section(c.fg, c.surface_container),
			z = section(c.bg, c.tertiary),
		},
		command = {
			a = section(c.on_primary, c.primary),
			b = section(c.fg, c.surface_container),
			c = section(c.fg, c.surface),
			x = section(c.fg, c.surface),
			y = section(c.fg, c.surface_container),
			z = section(c.on_primary, c.primary),
		},
		inactive = {
			a = { fg = c.muted, bg = c.surface_container },
			b = { fg = c.muted, bg = c.surface },
			c = { fg = c.muted, bg = c.surface },
			x = { fg = c.muted, bg = c.surface },
			y = { fg = c.muted, bg = c.surface },
			z = { fg = c.muted, bg = c.surface_container },
		},
	}
end

function M.setup()
	vim.opt.termguicolors = true
	load_base_theme()
	vim.g.colors_name = "matugen-tokyonight"

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

	-- Syntax stays close to tokyonight so the wallpaper palette does not wash out code.
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

	-- Lualine/winbar uses wallpaper accents over tokyonight surfaces for contrast.
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
