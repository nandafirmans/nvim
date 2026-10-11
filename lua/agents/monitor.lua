-- Agent monitor: a usage dashboard for every agent CLI. KPI tiles for the
-- whole window, one card per CLI (metrics and a 7-day bar chart), the share
-- of tokens per CLI and the top projects, plus what is live in the hub.
-- Data comes from lua/agents/stats.py, which reads each CLI's own files; a
-- CLI that is not installed or has no data yet gets a card that says so.
local C = require("agents.canvas")

local M = {}

local WINDOW_KEYS = { "today", "week", "month" }
local WINDOW_LABELS = { today = "Today", week = "7 days", month = "30 days" }
local EIGHTHS = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

-- Fixed palette (as in the office), so the dashboard looks the same in any colorscheme.
local P = {
	band = "#1f2330",
	tile = "#252a3a",
	card = "#1d2130",
	track = "#2c3245",
	text = "#e6e9f0",
	dim = "#8b95aa",
	faint = "#5d6680",
	accent = "#f6c453",
	accent_text = "#1d1f27",
	running = "#f6c453",
	waiting = "#f56565",
	done = "#68d391",
	cost = "#68d391",
}
local AGENT_COLORS = {
	claude = "#e8875b",
	omp = "#7aa2f7",
	pi = "#4fd1c5",
	opencode = "#9ece6a",
	codex = "#bb9af7",
	hermes = "#7dcfff",
}

local state = { window = "week", data = nil, error = nil, loading = false, buf = nil, tab = nil }

-- Highlights -----------------------------------------------------------------

local hl_cache = {}

local function hl(fg, bg, bold)
	local key = (fg or "-") .. (bg or "-") .. (bold and "b" or "")
	local name = hl_cache[key]
	if not name then
		name = "AgentsMon" .. key:gsub("[#-]", "")
		vim.api.nvim_set_hl(0, name, { fg = fg, bg = bg, bold = bold })
		hl_cache[key] = name
	end
	return name
end

function M.reset_colors()
	hl_cache = {}
end

-- Formatting -------------------------------------------------------------------

local function short(n)
	n = n or 0
	if n >= 1e9 then
		return ("%.1fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e3 then
		return ("%.1fk"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

local function ago(ts)
	if not ts then
		return "never"
	end
	local seconds = math.max(0, os.time() - math.floor(ts))
	if seconds < 60 then
		return "just now"
	elseif seconds >= 2 * 86400 then
		return math.floor(seconds / 86400) .. "d ago"
	end
	return C.age(seconds) .. " ago"
end

local function color_of(name)
	return AGENT_COLORS[name] or P.text
end

-- A block of `width` cells: segments padded (or cut) to fill it, on `bg`.
local function block(segs, width, bg)
	local out, used = {}, 0
	for _, seg in ipairs(segs) do
		local text = seg[1]
		local w = C.width(text)
		if used + w > width then
			text = C.trunc(text, width - used)
			w = C.width(text)
		end
		table.insert(out, { text, hl(seg[2] or P.text, seg.bg or bg, seg.bold) })
		used = used + w
		if used >= width then
			break
		end
	end
	if used < width then
		table.insert(out, { string.rep(" ", width - used), hl(nil, bg) })
	end
	return out
end

-- Left and right segments in one block.
local function split(left, right, width, bg)
	local lw = 0
	for _, s in ipairs(left) do
		lw = lw + C.width(s[1])
	end
	local rw = 0
	for _, s in ipairs(right) do
		rw = rw + C.width(s[1])
	end
	local segs = vim.list_extend({}, left)
	table.insert(segs, { string.rep(" ", math.max(1, width - lw - rw)) })
	return block(vim.list_extend(segs, right), width, bg)
end

-- Places blocks (each a list of lines, all `width` wide) side by side; a
-- shorter block is padded with `bg` so the columns stay aligned.
local function side_by_side(canvas, blocks, margin, gap, width, bg)
	local height = 0
	for _, b in ipairs(blocks) do
		height = math.max(height, #b)
	end
	for row = 1, height do
		local segs = { { string.rep(" ", margin) } }
		for i, b in ipairs(blocks) do
			if i > 1 then
				table.insert(segs, { string.rep(" ", gap) })
			end
			vim.list_extend(segs, b[row] or block({}, width, bg))
		end
		C.push(canvas, segs)
	end
end

-- Totals across CLIs for the KPI tiles.
local function totals(agents, window)
	local t = { tokens = 0, input = 0, output = 0, cache = 0, sessions = 0, prompts = 0, tools = 0, cost = 0, cost_known = false, active = 0 }
	for _, a in ipairs(agents) do
		local w = a.status == "ok" and a.windows and a.windows[window]
		if w then
			t.input, t.output, t.cache = t.input + w.input, t.output + w.output, t.cache + w.cache
			t.sessions, t.prompts, t.tools = t.sessions + w.sessions, t.prompts + w.prompts, t.tools + w.tool_calls
			if w.cost_known then
				t.cost, t.cost_known = t.cost + w.cost, true
			end
			if w.sessions > 0 or w.prompts > 0 then
				t.active = t.active + 1
			end
		end
	end
	t.tokens = t.input + t.output + t.cache
	return t
end

local function live_counts()
	local ok, agents = pcall(require, "agents")
	local hub = ok and agents._hub
	local per_tool, all = {}, { tabs = 0, running = 0, waiting = 0, done = 0 }
	if not hub then
		return per_tool, all
	end
	for _, agent in ipairs(hub.S.agents) do
		local status = hub.status_of(agent.name)
		local t = per_tool[agent.tool] or { tabs = 0, running = 0, waiting = 0, done = 0 }
		per_tool[agent.tool] = t
		t.tabs, all.tabs = t.tabs + 1, all.tabs + 1
		if t[status] then
			t[status], all[status] = t[status] + 1, all[status] + 1
		end
	end
	return per_tool, all
end

-- Pieces -----------------------------------------------------------------------

local function header(canvas, width)
	local updated = state.loading and "refreshing…"
		or (state.data and ("updated " .. os.date("%H:%M", math.floor(state.data.generated_at))) or "")
	C.push(canvas, split({ { "  ◆ AGENT MONITOR", P.accent, bold = true }, { "   usage across your agent CLIs", P.dim } }, {
		{ updated .. "  ", P.dim },
	}, width, P.band))
	local pills = { { "  " } }
	for i, key in ipairs(WINDOW_KEYS) do
		local active = key == state.window
		table.insert(pills, {
			(" %d %s "):format(i, WINDOW_LABELS[key]),
			active and P.accent_text or P.dim,
			bg = active and P.accent or P.track,
			bold = active,
		})
		table.insert(pills, { " " })
	end
	C.push(canvas, split(pills, { { "r refresh   q close  ", P.faint } }, width, P.band))
	C.push(canvas, block({}, width, P.band))
	C.push(canvas, { { "" } })
end

local function tile(label, value, sub, value_color, width)
	return {
		block({ { "  " .. label, P.dim } }, width, P.tile),
		block({ { "  " .. value, value_color or P.text, bold = true } }, width, P.tile),
		block({ { "  " .. (sub or ""), P.faint } }, width, P.tile),
	}
end

local function tiles(canvas, width, agents, live)
	local t = totals(agents, state.window)
	local items = {
		{ "TOKENS", short(t.input + t.output), ("in %s · out %s · cache %s"):format(short(t.input), short(t.output), short(t.cache)) },
		{ "SESSIONS", tostring(t.sessions), t.active .. " CLI" .. (t.active == 1 and "" or "s") .. " used" },
		{ "PROMPTS", tostring(t.prompts), short(t.tools) .. " tool calls" },
		{ "COST", t.cost_known and ("$%.2f"):format(t.cost) or "n/a", "where the CLI records it", t.cost_known and P.cost or P.dim },
		{
			"LIVE NOW",
			live.tabs .. " tab" .. (live.tabs == 1 and "" or "s"),
			("%d running · %d need you"):format(live.running, live.waiting),
			live.waiting > 0 and P.waiting or live.running > 0 and P.running or P.text,
		},
	}
	local gap = 2
	local count = math.max(1, math.min(#items, math.floor((width - 4 + gap) / (20 + gap))))
	local w = math.floor((width - 4 - gap * (count - 1)) / count)
	for start = 1, #items, count do
		local row = {}
		for i = start, math.min(start + count - 1, #items) do
			local it = items[i]
			table.insert(row, tile(it[1], it[2], it[3], it[4], w))
		end
		side_by_side(canvas, row, 2, gap, w, P.tile)
		C.push(canvas, { { "" } })
	end
end

-- 7-day bars, `rows` tall, one 3-cell column per day.
local function bars(values, rows, color, bg)
	local max = 0
	for _, v in ipairs(values) do
		max = math.max(max, v)
	end
	local lines = {}
	for r = rows, 1, -1 do
		local segs = {}
		for _, v in ipairs(values) do
			local eighths = max > 0 and math.floor(v / max * rows * 8 + 0.5) or 0
			local fill = math.max(0, math.min(8, eighths - (r - 1) * 8))
			if fill == 0 and r == 1 and v > 0 then
				fill = 1
			end
			local ch = fill == 0 and (r == 1 and "▁" or " ") or EIGHTHS[fill]
			table.insert(segs, { ch:rep(3), fill == 0 and P.track or color, bg = bg })
			table.insert(segs, { " ", bg = bg })
		end
		table.insert(lines, segs)
	end
	return lines
end

local function day_letters()
	local out = {}
	for i = 6, 0, -1 do
		table.insert(out, os.date("%a", os.time() - i * 86400):sub(1, 2))
	end
	return out
end

local function card(agent, live, width)
	local color = color_of(agent.name)
	local lines = {}
	local function add(segs)
		table.insert(lines, block(segs, width, P.card))
	end
	-- Two label/value columns; values get a fixed slot so long numbers never
	-- run into the next label.
	local function pair(l1, v1, l2, v2, c2)
		local left_w = math.max(19, math.floor(width / 2))
		local left = block({ { "  " .. vim.trim(l1), P.dim } }, 11, P.card)
		vim.list_extend(left, block({ { v1, P.text, bold = true } }, left_w - 11, P.card))
		local right = block({ { vim.trim(l2), P.dim } }, 9, P.card)
		vim.list_extend(right, block({ { v2, c2 or P.text, bold = true } }, width - left_w - 9, P.card))
		table.insert(lines, vim.list_extend(left, right))
	end

	local pill
	if live and live.tabs > 0 then
		local busy = live.running > 0 or live.waiting > 0
		pill = {
			(" %d live%s "):format(live.tabs, live.running > 0 and (" · " .. live.running .. " running") or ""),
			busy and P.accent_text or P.text,
			bg = busy and (live.waiting > 0 and P.waiting or P.running) or P.track,
		}
	elseif agent.status == "not_installed" then
		pill = { " not installed ", P.dim, bg = P.track }
	elseif not agent.installed and agent.status == "ok" then
		pill = { " not on PATH ", P.dim, bg = P.track }
	else
		pill = { " idle ", P.dim, bg = P.track }
	end
	table.insert(lines, split({ { " ▌", color }, { agent.name:upper(), color, bold = true } }, { pill, { " " } }, width, P.card))
	add({})

	local w = agent.status == "ok" and agent.windows and agent.windows[state.window]
	if not w then
		local note = ({
			not_installed = { "Not installed.", "Install " .. agent.name .. " and its usage appears here." },
			no_data = { "No usage recorded yet.", "Start " .. agent.name .. " from the hub (n) to see numbers." },
		})[agent.status] or { "Could not read its data.", agent.message or "unknown error" }
		for _ = 1, 3 do
			add({})
		end
		add({ { "  " .. note[1], agent.status == "error" and P.waiting or P.text } })
		add({ { "  " .. note[2], P.dim } })
		for _ = 1, 4 do
			add({})
		end
		return lines
	end

	pair("Sessions", tostring(w.sessions), "Prompts ", tostring(w.prompts))
	pair("Tools   ", short(w.tool_calls), "Cost    ", w.cost_known and ("$%.2f"):format(w.cost) or "n/a", w.cost_known and P.cost or P.dim)
	pair("Input   ", short(w.input), "Output  ", short(w.output))
	pair("Cache   ", short(w.cache), "Last    ", ago(agent.last_used))
	add({})
	for _, segs in ipairs(bars(agent.daily or {}, 3, color, P.card)) do
		add(vim.list_extend({ { "  " } }, segs))
	end
	local letters = { { "  " } }
	for _, d in ipairs(day_letters()) do
		table.insert(letters, { (" %s "):format(d):sub(1, 3), P.faint })
		table.insert(letters, { " " })
	end
	add(letters)
	return lines
end

local function share(canvas, width, agents)
	local items, total = {}, 0
	for _, a in ipairs(agents) do
		local w = a.status == "ok" and a.windows and a.windows[state.window]
		local tokens = w and (w.input + w.output) or 0
		if tokens > 0 then
			table.insert(items, { a.name, tokens })
			total = total + tokens
		end
	end
	C.push(canvas, { { "  " }, { "TOKEN SHARE", hl(P.text, nil, true) }, { "  input + output, " .. WINDOW_LABELS[state.window]:lower(), hl(P.faint) } })
	C.push(canvas, { { "" } })
	if total == 0 then
		C.push(canvas, { { "  No tokens in this window.", hl(P.dim) } })
		return
	end
	local bar_w = width - 4
	local segs, used = { { "  " } }, 0
	for i, it in ipairs(items) do
		local cells = i == #items and (bar_w - used) or math.max(1, math.floor(it[2] / total * bar_w + 0.5))
		cells = math.min(cells, bar_w - used)
		used = used + cells
		table.insert(segs, { ("█"):rep(cells), hl(color_of(it[1])) })
	end
	C.push(canvas, segs)
	local legend = { { "  " } }
	for _, it in ipairs(items) do
		vim.list_extend(legend, {
			{ "■ ", hl(color_of(it[1])) },
			{ it[1], hl(P.text) },
			{ (" %d%%   "):format(math.floor(it[2] / total * 100 + 0.5)), hl(P.dim) },
		})
	end
	C.push(canvas, legend)
end

local function projects(canvas, width, agents)
	local merged = {}
	for _, a in ipairs(agents) do
		for _, p in ipairs(a.projects or {}) do
			local entry = merged[p[1]] or { name = p[1], tokens = 0, by = {} }
			merged[p[1]] = entry
			entry.tokens = entry.tokens + p[2]
			entry.by[a.name] = (entry.by[a.name] or 0) + p[2]
		end
	end
	local list = vim.tbl_values(merged)
	table.sort(list, function(x, y)
		return x.tokens > y.tokens
	end)
	C.push(canvas, { { "  " }, { "TOP PROJECTS", hl(P.text, nil, true) }, { "  30 days, all CLIs, input + output", hl(P.faint) } })
	C.push(canvas, { { "" } })
	if #list == 0 or list[1].tokens == 0 then
		C.push(canvas, { { "  No projects yet.", hl(P.dim) } })
		return
	end
	local name_w, value_w = 22, 8
	local bar_w = math.max(10, width - 4 - name_w - value_w - 2)
	for i = 1, math.min(8, #list) do
		local p = list[i]
		local segs = { { "  " }, { C.trunc(p.name, name_w - 1) .. string.rep(" ", name_w - C.width(C.trunc(p.name, name_w - 1))), hl(P.text) } }
		local cells_total = math.max(1, math.floor(p.tokens / list[1].tokens * bar_w + 0.5))
		local used = 0
		local order = vim.tbl_keys(p.by)
		table.sort(order, function(x, y)
			return p.by[x] > p.by[y]
		end)
		for j, name in ipairs(order) do
			local cells = j == #order and (cells_total - used) or math.floor(p.by[name] / p.tokens * cells_total + 0.5)
			cells = math.max(0, math.min(cells, cells_total - used))
			used = used + cells
			table.insert(segs, { ("━"):rep(cells), hl(color_of(name)) })
		end
		table.insert(segs, { ("─"):rep(bar_w - used), hl(P.track) })
		table.insert(segs, { ("%" .. value_w .. "s"):format(short(p.tokens)), hl(P.dim) })
		C.push(canvas, segs)
	end
end

local function render()
	local buf = state.buf
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return
	end
	local win = vim.fn.bufwinid(buf)
	local width = win ~= -1 and vim.api.nvim_win_get_width(win) or vim.o.columns
	local canvas = C.new_canvas()

	header(canvas, width)
	if state.error then
		C.push(canvas, { { "  " .. state.error, hl(P.waiting) } })
	elseif not state.data then
		C.push(canvas, { { "  Reading usage from each agent…", hl(P.dim) } })
	else
		local agents = state.data.agents
		local per_tool, live = live_counts()
		tiles(canvas, width, agents, live)

		local gap = 2
		local per_row = math.max(1, math.floor((width - 4 + gap) / (36 + gap)))
		local card_w = math.floor((width - 4 - gap * (per_row - 1)) / per_row)
		for start = 1, #agents, per_row do
			local row = {}
			for i = start, math.min(start + per_row - 1, #agents) do
				table.insert(row, card(agents[i], per_tool[agents[i].name], card_w))
			end
			side_by_side(canvas, row, 2, gap, card_w, P.card)
			C.push(canvas, { { "" } })
		end

		share(canvas, width, agents)
		C.push(canvas, { { "" } })
		projects(canvas, width, agents)
		C.push(canvas, { { "" } })
		C.push(canvas, {
			{ "  Cost shows only where a CLI records it (omp, opencode, hermes with pricing). Cache = cached input re-read each turn.", hl(P.faint) },
		})
	end
	C.paint(buf, canvas)
end

function M.refresh()
	if state.loading then
		return
	end
	if vim.fn.executable("python3") == 0 then
		state.error = "python3 is needed to read agent usage."
		render()
		return
	end
	state.loading = true
	-- Next to this file, wherever the config is installed.
	local script = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/stats.py"
	local ok = pcall(vim.system, { "python3", "-I", script }, { text = true }, function(result)
		vim.schedule(function()
			state.loading = false
			local decoded, data = pcall(vim.json.decode, result.stdout or "")
			if result.code == 0 and decoded and type(data) == "table" then
				state.data, state.error = data, nil
			else
				state.error = "Could not read usage: " .. vim.trim(result.stderr or "invalid output")
			end
			render()
		end)
	end)
	if not ok then
		state.loading = false
		state.error = "Could not start python3 to read usage."
	end
	render()
end

function M.open()
	if state.tab and vim.api.nvim_tabpage_is_valid(state.tab) then
		vim.api.nvim_set_current_tabpage(state.tab)
		M.refresh()
		return
	end
	vim.cmd("tabnew")
	state.tab = vim.api.nvim_get_current_tabpage()
	local scratch = vim.api.nvim_get_current_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = "agentmonitor"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = false
	vim.api.nvim_win_set_buf(0, buf)
	pcall(vim.api.nvim_buf_delete, scratch, { force = true })
	local wo = vim.wo[0]
	wo.number, wo.relativenumber, wo.signcolumn, wo.wrap = false, false, "no", false
	wo.cursorline, wo.list, wo.spell = false, false, false
	wo.fillchars = "eob: "
	state.buf = buf

	local function map(lhs, fn)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true })
	end
	for i, key in ipairs(WINDOW_KEYS) do
		map(tostring(i), function()
			state.window = key
			render()
		end)
	end
	map("r", M.refresh)
	map("q", function()
		vim.cmd("tabclose")
	end)
	local group = vim.api.nvim_create_augroup("AgentsMonitor", { clear = true })
	vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, { group = group, callback = render })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			M.reset_colors()
			render()
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		callback = function()
			state.buf, state.tab = nil, nil
			pcall(vim.api.nvim_del_augroup_by_name, "AgentsMonitor")
		end,
	})
	M.refresh()
end

return M
