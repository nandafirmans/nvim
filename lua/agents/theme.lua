-- Shares the colorscheme with the phone pages (lua/agents/web). Every
-- colorscheme change writes its palette to <state>/theme.json and its name to
-- <state>/colorscheme. Every Neovim with the hub set up watches that name, so a
-- theme picked on the phone (or in another Neovim) applies everywhere, and the
-- last one comes back after a restart. "wallpaper" is core/walltheme.lua.
local M = {}

local uv = vim.uv or vim.loop
local WALLPAPER = "wallpaper"

local function state_dir()
	return vim.env.AGENTS_STATE or (vim.fn.expand("~") .. "/.local/state/agents")
end

local function path(name)
	return state_dir() .. "/" .. name
end

local function read(file)
	local f = io.open(file, "r")
	if not f then
		return nil
	end
	local data = f:read("*a")
	f:close()
	return data
end

-- Write through a temp file, so a reader never sees half of it.
local function write(file, data)
	if read(file) == data then
		return
	end
	vim.fn.mkdir(state_dir(), "p")
	local tmp = file .. ".tmp" .. uv.os_getpid()
	local f = io.open(tmp, "w")
	if not f then
		return
	end
	f:write(data)
	f:close()
	uv.fs_rename(tmp, file)
end

local function has_wallpaper()
	return uv.fs_stat(vim.fn.stdpath("config") .. "/lua/core/walltheme.lua") ~= nil
end

-- The name to save: "wallpaper" while core/walltheme.lua is the theme.
function M.current()
	if vim.g.walltheme_active then
		return WALLPAPER
	end
	return vim.g.colors_name
end

-- Every colorscheme on the runtimepath, the installed plugins first.
function M.list()
	local builtin = {}
	for _, file in ipairs(vim.fn.globpath(vim.env.VIMRUNTIME, "colors/*", false, true)) do
		builtin[vim.fn.fnamemodify(file, ":t:r")] = true
	end
	local mine, stock = {}, {}
	if has_wallpaper() then
		table.insert(mine, { name = WALLPAPER })
	end
	for _, name in ipairs(vim.fn.getcompletion("", "color")) do
		if builtin[name] then
			table.insert(stock, { name = name, builtin = true })
		else
			table.insert(mine, { name = name })
		end
	end
	return vim.list_extend(mine, stock)
end

function M.exists(name)
	if name == WALLPAPER then
		return has_wallpaper()
	end
	return vim.tbl_contains(vim.fn.getcompletion("", "color"), name)
end

function M.apply(name)
	if not name or name == "" or name == M.current() or not M.exists(name) then
		return false
	end
	if name == WALLPAPER then
		require("core.ui").reload_walltheme()
	else
		local ok, err = pcall(vim.cmd.colorscheme, name)
		if not ok then
			vim.notify("agents: colorscheme " .. name .. ": " .. tostring(err), vim.log.levels.WARN)
			return false
		end
	end
	return true
end

-- Palette ----------------------------------------------------------------------------

local function hex(n)
	return n and ("#%06x"):format(n) or nil
end

local function group(name)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	return ok and hl or {}
end

local function fg_of(...)
	for _, name in ipairs({ ... }) do
		local color = hex(group(name).fg)
		if color then
			return color
		end
	end
end

local function rgb(color)
	return tonumber(color:sub(2, 3), 16), tonumber(color:sub(4, 5), 16), tonumber(color:sub(6, 7), 16)
end

-- a, moved t of the way to b.
local function mix(a, b, t)
	local r1, g1, b1 = rgb(a)
	local r2, g2, b2 = rgb(b)
	local function ch(x, y)
		return math.floor(x + (y - x) * t + 0.5)
	end
	return ("#%02x%02x%02x"):format(ch(r1, r2), ch(g1, g2), ch(b1, b2))
end

local function valid(color)
	return type(color) == "string" and color:match("^#%x%x%x%x%x%x$") and color or nil
end

function M.palette()
	local light = vim.o.background == "light"
	local normal = group("Normal")
	local bg = hex(normal.bg)
	-- A transparent theme shows the terminal's background; the wallpaper
	-- theme knows the colour it was made for.
	if not bg and vim.g.walltheme_active then
		local ok, colors = pcall(require, "core.walltheme_colors")
		bg = ok and type(colors) == "table" and valid(colors.bg) or nil
	end
	bg = bg or hex(group("NormalFloat").bg) or valid(vim.g.terminal_color_0) or (light and "#ffffff" or "#1a1b26")
	local fg = hex(normal.fg) or (light and "#24292f" or "#c0caf5")
	local p = {
		bg = bg,
		fg = fg,
		muted = fg_of("Comment") or mix(fg, bg, 0.45),
		accent = fg_of("Function", "Title", "Keyword") or fg,
		accent2 = fg_of("Keyword", "Statement", "Special") or fg,
		ok = fg_of("DiagnosticOk", "String", "DiffAdd") or "#6fdc8c",
		warn = fg_of("DiagnosticWarn", "WarningMsg", "Number") or "#ffb547",
		err = fg_of("DiagnosticError", "ErrorMsg", "Error") or "#ff5a4e",
		info = fg_of("DiagnosticInfo", "Type", "Identifier") or "#7aa2f7",
		selection = hex(group("Visual").bg) or mix(bg, fg, 0.2),
		cursor = hex(group("Cursor").bg) or fg,
	}
	-- The 16 terminal colours: the theme's own, or ones made from its groups.
	local made = { bg, p.err, p.ok, p.warn, p.info, p.accent2, fg_of("Special", "Constant") or p.info, fg }
	p.terminal = {}
	for i = 0, 15 do
		local base = made[i % 8 + 1]
		if i == 8 then
			base = mix(bg, fg, 0.35)
		elseif i > 8 then
			base = mix(base, light and "#000000" or "#ffffff", 0.15)
		end
		p.terminal[i + 1] = valid(vim.g["terminal_color_" .. i]) or base
	end
	p.name = M.current()
	p.background = light and "light" or "dark"
	return p
end

-- Writes the palette and the theme list now (`nvim --headless` uses this).
function M.export()
	local name = M.current()
	if not name then
		return
	end
	write(path("themes.json"), vim.json.encode(M.list()))
	write(path("theme.json"), vim.json.encode(M.palette()))
	write(path("colorscheme"), name .. "\n")
end

local pending = false
-- A theme sets its highlights after the ColorScheme event (the wallpaper
-- theme does), and a picker's preview fires it on every move: wait a moment.
local function export_soon()
	if pending then
		return
	end
	pending = true
	vim.defer_fn(function()
		pending = false
		M.export()
	end, 300)
end

local function saved()
	local data = read(path("colorscheme"))
	return data and vim.trim(data) or nil
end

local watcher
local function watch()
	vim.fn.mkdir(state_dir(), "p")
	watcher = uv.new_fs_event()
	if not watcher then
		return
	end
	watcher:start(state_dir(), {}, function(_, file)
		if file ~= "colorscheme" then
			return
		end
		vim.schedule(function()
			M.apply(saved())
		end)
	end)
end

function M.pick()
	local items = M.list()
	vim.ui.select(items, {
		prompt = "Theme (also on the phone)",
		format_item = function(item)
			return item.name .. (item.name == M.current() and "  ●" or "") .. (item.builtin and "  (built-in)" or "")
		end,
	}, function(item)
		if item then
			M.apply(item.name)
		end
	end)
end

function M.setup(group_id)
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group_id,
		callback = function()
			vim.g.walltheme_active = vim.g.walltheme_loading == true
			export_soon()
		end,
	})
	vim.api.nvim_create_user_command("AgentsTheme", function(cmd)
		if cmd.args == "" then
			M.pick()
		elseif not M.exists(cmd.args) then
			vim.notify("agents: no colorscheme " .. cmd.args, vim.log.levels.WARN)
		else
			M.apply(cmd.args)
		end
	end, {
		nargs = "?",
		desc = "Pick the colorscheme (shared with the phone pages)",
		complete = function(lead)
			return vim.tbl_filter(function(name)
				return vim.startswith(name, lead)
			end, vim.tbl_map(function(item)
				return item.name
			end, M.list()))
		end,
	})
	-- The last theme picked anywhere, over the startup one.
	if not M.apply(saved()) then
		export_soon()
	end
	watch()
end

return M
