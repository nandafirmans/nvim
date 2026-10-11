-- Agent office: a pixel-art floor plan where every tab is a coworker.
-- Each terminal cell holds two pixels ("▀" with fg = top, bg = bottom), so
-- the art stays solid whatever the font's line height. Desks (projects) get
-- cubicles with their own carpet colour; idle coworkers walk to the break
-- rooms. Inspired by github.com/alminisl/agent-office.
local C = require("agents.canvas")

local M = {}

local CUBE = 22 -- cubicle width in cells
local CUBE_ROWS = 11 -- bubble, 7 rows of cubicle, 2 nameplate rows, spacer
local ROOM_ROWS = 9
local YOUR_TURN_SECONDS = 5 * 60 -- after this a finished agent goes on a break

-- Palette --------------------------------------------------------------------

local P = {
	floor_a = "#3e4b5e",
	floor_b = "#3a4658",
	wall = "#1f2330",
	band = "#2a3142",
	back_wall = "#dccaa3",
	back_edge = "#b9a67f",
	partition = "#5d6680",
	selected = "#f6c453",
	desk = "#a8743f",
	desk_front = "#7c532b",
	monitor = "#161821",
	screen_off = "#2d3243",
	chair = "#2b3245",
	leaf = "#4fbf7a",
	leaf_dark = "#2f8a55",
	pot = "#a0522d",
	mug = "#f4f4f4",
	eye = "#1b1b1b",
	mouth = "#9b2c2c",
	pants = "#2d3748",
	plate = "#191c27",
	text = "#e6e9f0",
	dim = "#8b95aa",
	bubble = "#f3f3f3",
	bubble_text = "#1d1f27",
	bubble_wait = "#fbd38d",
	bubble_done = "#c6f6d5",
	running = "#f6c453",
	waiting = "#f56565",
	done = "#68d391",
	idle = "#8b95aa",
	add = "#68d391",
	del = "#f56565",
}

local SCREENS = {
	running = { base = "#3fb6d3", light = "#c9f4ff", dark = "#1f7f99" },
	waiting = { base = "#f6ad55", light = "#fff1d6", dark = "#c0782a" },
	done = { base = "#48bb78", light = "#d8f8e4", dark = "#2f855a" },
}

local CARPETS = { "#b4487c", "#2f9c95", "#7a52c0", "#3f6fc4", "#c0703a", "#4f9a55" }
local SKINS = { "#f5d0a9", "#e8b88a", "#c68642", "#8d5524" }
local HAIRS = { "#2d1b0e", "#4a3020", "#b7791f", "#1a202c", "#c53030", "#a0aec0" }
local SHIRTS = { "#4299e1", "#ed8936", "#9f7aea", "#38b2ac", "#f56565", "#ecc94b", "#68d391" }

local ROOMS = {
	{ id = "kitchen", title = "KITCHEN", breaks = { "Coffee break", "Getting snacks", "At the water cooler" } },
	{ id = "gym", title = "GAME ROOM", breaks = { "Playing ping pong", "At the gym", "Stretching" } },
	{ id = "lounge", title = "LOUNGE", breaks = { "On the sofa", "Reading a book", "Napping" } },
}

-- Helpers --------------------------------------------------------------------

local function hash(text)
	local h = 0
	for i = 1, #text do
		h = (h * 31 + text:byte(i)) % 2147483647
	end
	return h
end

local function pick(list, key)
	return list[(hash(key) % #list) + 1]
end

local function shade(hex, factor)
	local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
	local function f(v)
		return math.max(0, math.min(255, math.floor(v * factor + 0.5)))
	end
	return ("#%02x%02x%02x"):format(f(r), f(g), f(b))
end

function M.project_hl(project)
	return ({ "AgentsP1", "AgentsP2", "AgentsP3", "AgentsP4", "AgentsP5", "AgentsP6" })[(hash(project) % 6) + 1]
end

local function carpet(project)
	return CARPETS[(hash(project) % #CARPETS) + 1]
end

-- One highlight group per (fg, bg) pair, created on demand. A colorscheme
-- change clears them, so the cache is dropped then (see M.reset_colors).
local hl_cache = {}

function M.reset_colors()
	hl_cache = {}
end

local function hl(fg, bg)
	local key = (fg or "-") .. (bg or "-")
	local name = hl_cache[key]
	if not name then
		name = "AgentsPx" .. key:gsub("[#-]", "")
		vim.api.nvim_set_hl(0, name, { fg = fg, bg = bg })
		hl_cache[key] = name
	end
	return name
end

-- Framebuffer ----------------------------------------------------------------

local function framebuffer(width, rows)
	return { w = width, rows = rows, h = rows * 2, px = {}, text = {} }
end

local function set(fb, x, y, color)
	if x >= 0 and x < fb.w and y >= 0 and y < fb.h then
		fb.px[y * fb.w + x] = color
	end
end

local function rect(fb, x, y, w, h, color)
	for yy = y, y + h - 1 do
		for xx = x, x + w - 1 do
			set(fb, xx, yy, color)
		end
	end
end

-- Draws rows of palette keys; "." is transparent.
local function sprite(fb, x, y, rows, palette)
	for dy, line in ipairs(rows) do
		for dx = 1, #line do
			local key = line:sub(dx, dx)
			if key ~= "." then
				set(fb, x + dx - 1, y + dy - 1, palette[key])
			end
		end
	end
end

-- Text on a cell row; without bg the text sits on the pixels below it.
local function text(fb, row, col, str, fg, bg, max)
	if row < 0 or row >= fb.rows then
		return col
	end
	fb.text[row] = fb.text[row] or {}
	local chars = vim.fn.split(str, "\\zs")
	for i, ch in ipairs(chars) do
		local x = col + i - 1
		if x >= fb.w or (max and i > max) then
			break
		end
		fb.text[row][x] = { ch, fg, bg }
	end
	return col + #chars
end

local function to_canvas(fb, canvas)
	for row = 0, fb.rows - 1 do
		local segs, cur_text, cur_hl = {}, {}, nil
		local function flush()
			if cur_hl then
				table.insert(segs, { table.concat(cur_text), cur_hl })
			end
			cur_text = {}
		end
		for x = 0, fb.w - 1 do
			local top = fb.px[(row * 2) * fb.w + x] or P.wall
			local bottom = fb.px[(row * 2 + 1) * fb.w + x] or P.wall
			local cell = fb.text[row] and fb.text[row][x]
			local ch, group
			if cell then
				ch, group = cell[1], hl(cell[2], cell[3] or top)
			elseif top == bottom then
				ch, group = " ", hl(nil, top)
			else
				ch, group = "▀", hl(top, bottom)
			end
			if group ~= cur_hl then
				flush()
				cur_hl = group
			end
			table.insert(cur_text, ch)
		end
		flush()
		C.push(canvas, segs)
	end
end

-- Sprites ----------------------------------------------------------------------

local function looks(agent)
	return {
		h = pick(HAIRS, agent.name .. "hair"),
		s = pick(SKINS, agent.name .. "skin"),
		c = pick(SHIRTS, agent.name .. "shirt"),
		e = P.eye,
		m = P.mouth,
		p = P.pants,
	}
end

local HEAD = {
	".hhhh.",
	"hhhhhh",
	"hsssss",
	"sesses",
	".ssss.",
}
local HEAD_HAPPY = {
	".hhhh.",
	"hhhhhh",
	"hsssss",
	"sesses",
	".smms.",
}
local HEAD_SLEEPY = {
	".hhhh.",
	"hhhhhh",
	"hsssss",
	"sssss.",
	".ssss.",
}

local function seated(fb, x, y, agent, state, frame)
	local palette = looks(agent)
	sprite(fb, x, y, state == "done" and HEAD_HAPPY or HEAD, palette)
	rect(fb, x, y + 5, 6, 3, palette.c)
	if state == "running" then
		-- Typing: hands bounce on the desk.
		local l, r = frame == 0 and 0 or 1, frame == 0 and 5 or 4
		set(fb, x + l, y + 7, palette.s)
		set(fb, x + r, y + 7, palette.s)
	elseif state == "waiting" then
		-- Hand up: needs you.
		rect(fb, x + 6, y - 2, 1, 3, palette.s)
		rect(fb, x + 6, y + 1, 1, 5, palette.c)
	end
end

local function standing(fb, x, y, agent, frame)
	local palette = looks(agent)
	sprite(fb, x, y, HEAD_SLEEPY, palette)
	rect(fb, x, y + 5, 6, 4, palette.c)
	set(fb, x - 1 + frame, y + 6, palette.s)
	rect(fb, x + 1, y + 9, 1, 3, palette.p)
	rect(fb, x + 4, y + 9, 1, 3, palette.p)
end

-- Office pieces ----------------------------------------------------------------

local function floor(fb, night)
	local a, b = P.floor_a, P.floor_b
	if night then
		a, b = shade(a, 0.75), shade(b, 0.75)
	end
	for y = 0, fb.h - 1 do
		for x = 0, fb.w - 1 do
			set(fb, x, y, (math.floor(x / 2) + math.floor(y / 2)) % 2 == 0 and a or b)
		end
	end
end

local function mood(status, since)
	if status == "done" and os.time() - since >= YOUR_TURN_SECONDS then
		return "break_waiting"
	end
	if status == "idle" then
		return "break"
	end
	return status
end

local function break_of(agent)
	local slot = math.floor(os.time() / 600)
	local room = ROOMS[(hash(agent.name .. slot) % #ROOMS) + 1]
	return room, pick(room.breaks, agent.name .. slot)
end

local function bubble(agent, state, ctx)
	if state == "running" then
		return agent.activity_text or ctx.tails[agent.name] or "Working…", P.bubble
	elseif state == "waiting" then
		return "! " .. (agent.activity_text or "needs you"), P.bubble_wait
	elseif state == "done" then
		return "your turn", P.bubble_done
	elseif state == "exited" then
		return "Out of office", P.bubble
	end
end

local function cubicle(fb, cx, row, agent, ctx, night)
	local status = ctx.status_of(agent.name)
	local since = ctx.since(agent.name)
	local state = mood(status, since)
	local frame = math.floor(ctx.tick / 4) % 2
	local selected = agent.name == ctx.selected
	local y0 = (row + 1) * 2
	local away = state == "exited"

	-- Carpet, back wall with shelf and plant, partitions.
	local rug = carpet(agent.project)
	if night or away then
		rug = shade(rug, 0.7)
	end
	local rug_b = shade(rug, 0.88)
	for y = y0, y0 + 13 do
		for x = cx, cx + CUBE - 1 do
			set(fb, x, y, (math.floor(x / 2) + math.floor(y / 2)) % 2 == 0 and rug or rug_b)
		end
	end
	rect(fb, cx, y0, CUBE, 3, night and shade(P.back_wall, 0.75) or P.back_wall)
	rect(fb, cx, y0 + 3, CUBE, 1, P.back_edge)
	for i, color in ipairs({ "#e53e3e", "#3182ce", "#d69e2e", "#38a169", "#805ad5" }) do
		rect(fb, cx + 2 + i, y0, 1, 3, color)
	end
	sprite(fb, cx + CUBE - 5, y0 + 1, { ".l.", "lLl", "LlL", ".p.", "ppp" }, { l = P.leaf, L = P.leaf_dark, p = P.pot })
	local edge = selected and P.selected or P.partition
	rect(fb, cx, y0, 1, 14, edge)
	rect(fb, cx + CUBE - 1, y0, 1, 14, edge)
	if selected then
		rect(fb, cx, y0 + 13, CUBE, 1, P.selected)
	end

	-- Chair, coworker, monitor, desk.
	local px = cx + 13
	rect(fb, px - 1, y0 + 5, 8, 6, P.chair)
	if state == "running" or state == "waiting" or state == "done" then
		seated(fb, px, y0 + 4, agent, state, frame)
	end

	local mx, my = cx + 3, y0 + 5
	rect(fb, mx, my, 8, 5, P.monitor)
	local screen = SCREENS[state]
	if screen then
		rect(fb, mx + 1, my + 1, 6, 3, screen.base)
		if state == "running" then
			-- Scrolling code.
			for i = 0, 5 do
				local on = (i + frame) % 3 ~= 0
				set(fb, mx + 1 + i, my + 1, on and screen.light or screen.base)
				set(fb, mx + 1 + i, my + 3, ((i + frame) % 2 == 0) and screen.dark or screen.base)
			end
		elseif state == "waiting" then
			rect(fb, mx + 3, my + 1, 2, 1, frame == 0 and screen.light or screen.base)
			set(fb, mx + 3, my + 3, screen.light)
		else
			set(fb, mx + 2, my + 2, screen.light)
			set(fb, mx + 3, my + 3, screen.light)
			set(fb, mx + 4, my + 2, screen.light)
			set(fb, mx + 5, my + 1, screen.light)
		end
	else
		rect(fb, mx + 1, my + 1, 6, 3, P.screen_off)
	end
	rect(fb, mx + 3, my + 5, 2, 1, P.monitor)
	rect(fb, cx + 2, y0 + 11, CUBE - 4, 1, P.desk)
	rect(fb, cx + 2, y0 + 12, CUBE - 4, 1, P.desk_front)
	if state == "break" or state == "break_waiting" then
		-- Mug left on the desk.
		set(fb, px + 2, y0 + 10, P.mug)
		set(fb, px + 3, y0 + 10, P.mug)
	end

	-- Speech bubble above the cubicle.
	local say, bg = bubble(agent, state, ctx)
	local info_now = ctx.context_of and ctx.context_of(agent)
	if info_now and info_now.percent >= 80 and (state == "done" or state == "break_waiting") then
		say, bg = "maybe /compact?", P.bubble_wait
	end
	if say then
		say = " " .. C.trunc(say, CUBE - 3) .. " "
		text(fb, row, cx + 1, say, P.bubble_text, bg)
	end

	-- Nameplate.
	local spec = ctx.STATUS[status]
	local dot = ({ running = P.running, waiting = P.waiting, done = P.done })[status] or P.idle
	local r1, r2 = row + 8, row + 9
	rect(fb, cx, r1 * 2, CUBE, 4, P.plate)
	text(fb, r1, cx, "▌", rug)
	local stat, stat_w = {}, 0
	local changes = ctx.changes_of(agent)
	if changes then
		if changes.add > 0 then
			table.insert(stat, { "+" .. changes.add, P.add })
		end
		if changes.del > 0 then
			table.insert(stat, { "−" .. changes.del, P.del })
		end
		for i, s in ipairs(stat) do
			stat_w = stat_w + vim.fn.strchars(s[1]) + (i > 1 and 1 or 0)
		end
	end
	local col = text(fb, r1, cx + 2, "● ", dot)
	local room_for_name = CUBE - (col - cx) - stat_w - 2
	text(fb, r1, col, C.trunc(ctx.display_name(agent), room_for_name), selected and P.selected or P.text)
	local sc = cx + CUBE - 1 - stat_w
	for _, s in ipairs(stat) do
		sc = text(fb, r1, sc, s[1], s[2]) + 1
	end
	text(fb, r2, cx, "▌", rug)
	local label = spec.label
	if status ~= "running" then
		label = label .. " " .. C.age(os.time() - since)
	end
	col = text(fb, r2, cx + 2, label, dot)
	-- Context window use (Claude), right-aligned; the task fills the gap.
	local info = ctx.context_of and ctx.context_of(agent)
	local ctx_text = info and (info.percent .. "%") or ""
	local ctx_col = cx + CUBE - 1 - vim.fn.strchars(ctx_text)
	if agent.task then
		text(fb, r2, col, " · " .. C.trunc(agent.task, math.max(0, ctx_col - col - 4)), P.dim)
	end
	if info then
		local color = info.percent >= 80 and P.waiting or info.percent >= 60 and P.running or P.dim
		text(fb, r2, ctx_col, ctx_text, color)
	end
	return { name = agent.name, top = row + 1, bottom = row + 10, left = cx + 1, right = cx + CUBE }
end

local function room(fb, x, row, w, spec, guests, ctx, night)
	local y0 = row * 2
	local h = ROOM_ROWS * 2
	local dim = night and 0.75 or 1
	if spec.id == "kitchen" then
		for y = y0, y0 + h - 1 do
			for xx = x, x + w - 1 do
				set(fb, xx, y, shade((math.floor(xx / 2) + math.floor(y / 2)) % 2 == 0 and "#e8e2d0" or "#c9bfa4", dim))
			end
		end
		rect(fb, x, y0 + 2, w, 3, shade("#9aa5b8", dim)) -- counter
		rect(fb, x + w - 5, y0 + 1, 4, 9, shade("#f0f0f0", dim)) -- fridge
		rect(fb, x + 2, y0 + 1, 3, 2, "#2d2d2d") -- coffee machine
		set(fb, x + 3, y0 + 1, "#e53e3e")
		rect(fb, x + math.floor(w / 2) - 4, y0 + 9, 8, 3, shade("#a8743f", dim)) -- table
	elseif spec.id == "gym" then
		for y = y0, y0 + h - 1 do
			for xx = x, x + w - 1 do
				set(fb, xx, y, shade((math.floor(xx / 2) + math.floor(y / 2)) % 2 == 0 and "#6b46a1" or "#5e3d8f", dim))
			end
		end
		local tx = x + math.floor(w / 2) - 6
		rect(fb, tx, y0 + 6, 12, 5, "#2f855a") -- ping pong table
		rect(fb, tx + 6, y0 + 5, 1, 7, "#f7fafc") -- net
		rect(fb, x + 2, y0 + 1, 2, 4, "#2d2d2d") -- arcade
		rect(fb, x + 2, y0 + 1, 2, 1, "#ed8936")
	else
		for y = y0, y0 + h - 1 do
			for xx = x, x + w - 1 do
				set(fb, xx, y, shade(xx % 6 < 3 and "#9c6b3c" or "#8d5f33", dim))
			end
		end
		local sx = x + math.floor(w / 2) - 7
		rect(fb, sx, y0 + 2, 14, 2, "#2c7a7b") -- sofa back
		rect(fb, sx, y0 + 4, 14, 2, "#38a3a5") -- seat
		rect(fb, sx + 2, y0 + 9, 10, 4, "#c05621") -- rug
		rect(fb, x + 2, y0 + 1, 3, 8, "#6b4226") -- bookcase
		rect(fb, x + 3, y0 + 2, 1, 2, "#e53e3e")
		rect(fb, x + 3, y0 + 5, 1, 2, "#3182ce")
	end
	rect(fb, x, y0, w, 1, P.wall)
	text(fb, row, x + 1, " " .. spec.title .. " ", P.text, P.wall)

	local rects = {}
	local frame = math.floor(ctx.tick / 8) % 2
	local slot = math.max(8, math.floor((w - 2) / math.max(1, #guests)))
	for i, guest in ipairs(guests) do
		local gx = x + 2 + (i - 1) * slot
		if gx + 6 < x + w then
			standing(fb, gx, y0 + 4, guest.agent, frame)
			text(fb, row + ROOM_ROWS - 1, gx - 1, " " .. C.trunc(ctx.display_name(guest.agent), slot - 2) .. " ", P.text, P.plate)
			table.insert(rects, { name = guest.agent.name, top = row + 2, bottom = row + ROOM_ROWS, left = gx, right = gx + 7 })
		end
	end
	return rects
end

-- Render -------------------------------------------------------------------------

-- Renders the office into a canvas; returns it with hit rectangles
-- (1-based lines and display columns) for <CR> and mouse clicks.
function M.render(agents, width, ctx)
	local hour = tonumber(os.date("%H"))
	local night = hour >= 19 or hour < 6
	local per_row = math.max(1, math.floor((width - 2) / (CUBE + 2)))
	local margin = math.floor((width - (per_row * (CUBE + 2) - 2)) / 2)

	local desks, order = {}, {}
	for _, agent in ipairs(agents) do
		if not desks[agent.project] then
			desks[agent.project] = {}
			table.insert(order, agent.project)
		end
		table.insert(desks[agent.project], agent)
	end

	-- Each desk is a zone of cubicles; zones are packed left to right in
	-- shelves, so small desks share a row instead of leaving it half empty.
	local zones = {}
	for _, project in ipairs(order) do
		local members = desks[project]
		local cols = math.min(#members, per_row)
		table.insert(zones, {
			project = project,
			members = members,
			cols = cols,
			w = cols * (CUBE + 2),
			h = 1 + math.ceil(#members / per_row) * CUBE_ROWS,
		})
	end
	local shelves, shelf = {}, nil
	for _, zone in ipairs(zones) do
		if not shelf or shelf.w + zone.w > per_row * (CUBE + 2) then
			shelf = { zones = {}, w = 0, h = 0 }
			table.insert(shelves, shelf)
		end
		zone.x = margin + shelf.w
		shelf.w = shelf.w + zone.w
		shelf.h = math.max(shelf.h, zone.h)
		table.insert(shelf.zones, zone)
	end

	local rows = 3
	for _, s in ipairs(shelves) do
		rows = rows + s.h
	end
	rows = rows + ROOM_ROWS + 1
	if #agents == 0 then
		rows = rows + 4
	end

	local fb = framebuffer(width, rows)
	floor(fb, night)

	-- Header band.
	rect(fb, 0, 0, width, 4, P.wall)
	local counts = { working = 0, waiting = 0, resting = 0 }
	local guests = { kitchen = {}, gym = {}, lounge = {} }
	for _, agent in ipairs(agents) do
		local state = mood(ctx.status_of(agent.name), ctx.since(agent.name))
		if state == "running" then
			counts.working = counts.working + 1
		elseif state == "waiting" then
			counts.waiting = counts.waiting + 1
		elseif state == "break" or state == "break_waiting" then
			counts.resting = counts.resting + 1
			local spec = break_of(agent)
			table.insert(guests[spec.id], { agent = agent })
		end
	end
	text(fb, 0, 1, "AGENT OFFICE", P.selected)
	local clock = os.date("%H:%M") .. (night and "  ☾ night shift" or "  ☀ day")
	text(fb, 0, width - vim.fn.strchars(clock) - 1, clock, P.dim)
	local col = text(fb, 1, 1, counts.working .. " working", P.running)
	col = text(fb, 1, col, "  ·  ", P.dim)
	col = text(fb, 1, col, counts.waiting .. " need you", counts.waiting > 0 and P.waiting or P.dim)
	col = text(fb, 1, col, "  ·  ", P.dim)
	text(fb, 1, col, counts.resting .. " on a break", P.dim)

	local rects = {}
	local row = 3
	if #agents == 0 then
		text(fb, row + 1, 2, "The office is empty. Press n in the sidebar to hire an agent.", P.text)
		row = row + 4
	end
	for _, s in ipairs(shelves) do
		for _, zone in ipairs(s.zones) do
			local label_w = zone.w - 2
			rect(fb, zone.x, row * 2, label_w, 2, P.band)
			text(fb, row, zone.x, "▌ ", carpet(zone.project))
			local c = text(fb, row, zone.x + 2, C.trunc(zone.project, label_w - 10), P.text)
			local n = #zone.members
			text(fb, row, c, "  " .. n .. (n == 1 and " seat" or " seats"), P.dim, nil, zone.x + label_w - c)
			for i, agent in ipairs(zone.members) do
				local slot = (i - 1) % per_row
				local line = math.floor((i - 1) / per_row)
				local cx = zone.x + slot * (CUBE + 2)
				table.insert(rects, cubicle(fb, cx, row + 1 + line * CUBE_ROWS, agent, ctx, night))
			end
		end
		row = row + s.h
	end

	-- Break rooms along the bottom.
	local room_w = math.floor((width - 4) / 3)
	for i, spec in ipairs(ROOMS) do
		local x = 1 + (i - 1) * (room_w + 1)
		vim.list_extend(rects, room(fb, x, row, room_w, spec, guests[spec.id], ctx, night))
	end

	local canvas = C.new_canvas()
	to_canvas(fb, canvas)
	return canvas, rects
end

function M.hit(rects, lnum, col)
	for _, r in ipairs(rects) do
		if lnum >= r.top and lnum <= r.bottom and col >= r.left and col <= r.right then
			return r.name
		end
	end
end

return M
