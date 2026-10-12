-- Autopilot: a queue of prompts per agent tab, sent one after another. The
-- next prompt goes out once the agent has worked on the previous one and
-- finished (status done, or idle for CLIs without hooks). It pauses by
-- itself when the agent needs input, hits a limit, exits, or does not pick
-- a prompt up; s starts and stops it. Queues are saved, so they survive a
-- Neovim restart, and the view lists them by folder.
local C = require("agents.canvas")

local M = {}

local hub
local NO_RESPONSE_SECONDS = 90 -- a sent prompt the agent never started on
local PAUSE_ON = {
	waiting = "the agent needs input",
	limited = "the agent hit its usage limit",
	exited = "the agent exited",
}

-- name -> { cwd, project, tool, label, running, reason, items = { { text, state, sent_at, started, done_at } } }
local queues = {}
local view = { buf = nil, win = nil, line_map = {} }

local function path()
	local dir = vim.fn.stdpath("data") .. "/agents"
	vim.fn.mkdir(dir, "p")
	return dir .. "/queues.json"
end

local function save()
	-- Queues with no prompts are only shown, never stored.
	local stored = {}
	for name, q in pairs(queues) do
		if #q.items > 0 then
			stored[name] = q
		end
	end
	local ok, encoded = pcall(vim.json.encode, stored)
	if ok then
		pcall(vim.fn.writefile, { encoded }, path())
	end
end

local function load()
	local ok, lines = pcall(vim.fn.readfile, path())
	if not ok or #lines == 0 then
		return
	end
	local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	if decoded_ok and type(data) == "table" then
		queues = data
	end
end

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Autopilot" })
end

local render

-- Queue model -----------------------------------------------------------------

local function queue_for(agent)
	local q = queues[agent.name]
	if not q then
		q = { items = {}, running = false }
		queues[agent.name] = q
	end
	-- Keep the folder and names current for the view.
	q.cwd, q.project, q.tool, q.label = agent.cwd, agent.project, agent.tool, hub.display_name(agent)
	return q
end

local function counts(q)
	local done, total = 0, 0
	for _, item in ipairs(q.items) do
		if item.state ~= "skipped" then
			total = total + 1
			if item.state == "done" then
				done = done + 1
			end
		end
	end
	return done, total
end

local function current(q)
	for _, item in ipairs(q.items) do
		if item.state == "sent" then
			return item
		end
	end
end

local function next_pending(q)
	for _, item in ipairs(q.items) do
		if item.state == "pending" then
			return item
		end
	end
end

local function pause(name, reason, quiet)
	local q = queues[name]
	if not q or not q.running then
		return
	end
	q.running, q.reason = false, reason
	save()
	if not quiet then
		local agent = hub.S.by_name[name]
		notify(("Paused %s: %s"):format(agent and hub.agent_label(agent) or name, reason), vim.log.levels.WARN)
		require("agents.flow").system_notify(q.project or "Autopilot", (q.label or name) .. " paused: " .. reason)
	end
	if render then
		render()
	end
end

-- Sends the next pending prompt, or finishes the queue.
local function send_next(name)
	local q = queues[name]
	local agent = hub.S.by_name[name]
	if not (q and q.running and agent) then
		return
	end
	local item = next_pending(q)
	if not item then
		q.running, q.reason = false, "finished"
		save()
		local done, total = counts(q)
		notify(("Finished %s: %d/%d prompts"):format(hub.agent_label(agent), done, total))
		require("agents.flow").system_notify(agent.project, ("%s finished its queue (%d prompts)"):format(hub.display_name(agent), done))
		return
	end
	item.state, item.sent_at, item.started = "sent", os.time(), false
	save()
	require("agents.flow").submit(name, item.text)
	if render then
		render()
	end
end

-- Engine ----------------------------------------------------------------------

-- Called by the hub on every status change of a tab.
function M.on_status(agent, before, after)
	local q = queues[agent.name]
	if not (q and q.running) then
		return
	end
	local item = current(q)
	if after == "running" then
		if item then
			item.started = true
			save()
		end
		return
	end
	if PAUSE_ON[after] then
		pause(agent.name, PAUSE_ON[after])
		return
	end
	if after ~= "done" and after ~= "idle" then
		return
	end
	if not item then
		-- Started while the agent was busy: its turn is over, begin now.
		send_next(agent.name)
	elseif item.started then
		-- Finished a turn: done (hooks) or idle (screen activity) after working.
		item.state, item.done_at = "done", os.time()
		save()
		send_next(agent.name)
	end
end

-- Called by the hub every poll: catches prompts the agent never picked up,
-- and tabs that were killed.
function M.tick()
	for name, q in pairs(queues) do
		if q.running then
			local agent = hub.S.by_name[name]
			local item = current(q)
			if not agent then
				pause(name, "the tab was closed")
			elseif item and not item.started and os.time() - (item.sent_at or 0) > NO_RESPONSE_SECONDS then
				pause(name, "the agent did not start on the prompt")
			end
		end
	end
end

function M.start(name)
	local q = queues[name]
	local agent = hub.S.by_name[name]
	if not (q and agent) then
		return
	end
	if not next_pending(q) and not current(q) then
		notify("Nothing queued for " .. hub.agent_label(agent) .. "; press a to add prompts", vim.log.levels.WARN)
		return
	end
	q.running, q.reason = true, nil
	save()
	local status = hub.status_of(name)
	local item = current(q)
	if item then
		-- Resume: the prompt in flight was already sent; it counts as done once
		-- the agent is idle, else the queue continues when it finishes.
		if status == "done" or status == "idle" then
			item.state, item.done_at = "done", os.time()
			send_next(name)
		else
			item.started = true
		end
	elseif status == "running" or status == "waiting" then
		-- Busy, or you are answering its question: carry on when it finishes.
		notify(hub.agent_label(agent) .. " is busy; the queue continues when it finishes")
	elseif PAUSE_ON[status] then
		pause(name, PAUSE_ON[status])
	else
		send_next(name)
	end
	if render then
		render()
	end
end

function M.stop(name)
	pause(name, "stopped by you", true)
	notify("Stopped autopilot for " .. ((queues[name] or {}).label or name))
end

function M.toggle(name)
	local q = queues[name]
	if q and q.running then
		M.stop(name)
	else
		M.start(name)
	end
end

function M.stop_all()
	local stopped = 0
	for name, q in pairs(queues) do
		if q.running then
			pause(name, "stopped by you", true)
			stopped = stopped + 1
		end
	end
	notify(("Stopped %d autopilot queue%s"):format(stopped, stopped == 1 and "" or "s"))
end

-- For the sidebar: "▶ 2/4" while running, "⏸ 2/4" when paused with prompts left.
function M.badge(name)
	local q = queues[name]
	if not q or #q.items == 0 then
		return nil
	end
	local done, total = counts(q)
	if q.running then
		return ("▶ %d/%d"):format(done, total), "AgentsRunning"
	elseif next_pending(q) or current(q) then
		return ("⏸ %d/%d"):format(done, total), "AgentsDim"
	end
end

-- View -------------------------------------------------------------------------

local STATE_MARK = {
	done = { "✓", "AgentsDone" },
	sent = { "▸", "AgentsRunning" },
	pending = { "·", "AgentsDim" },
	skipped = { "–", "AgentsDim" },
}

local function short_path(p)
	return p and vim.fn.fnamemodify(p, ":~") or "?"
end

render = function()
	local buf = view.buf
	if not (buf and vim.api.nvim_buf_is_valid(buf) and view.win and vim.api.nvim_win_is_valid(view.win)) then
		return
	end
	local width = vim.api.nvim_win_get_width(view.win)
	local canvas = C.new_canvas()
	view.line_map = {}

	-- Groups by folder; inside a folder, one block per agent tab.
	local folders, order = {}, {}
	local selected = hub.selected_agent()
	if selected then
		queue_for(selected)
	end
	for name, q in pairs(queues) do
		local folder = q.cwd or "?"
		if not folders[folder] then
			folders[folder] = {}
			table.insert(order, folder)
		end
		table.insert(folders[folder], name)
	end
	table.sort(order)

	local running, paused = 0, 0
	for _, q in pairs(queues) do
		if q.running then
			running = running + 1
		elseif next_pending(q) then
			paused = paused + 1
		end
	end
	C.push(canvas, C.row({ { " AUTOPILOT", "AgentsTitle" }, { "  prompts sent one after another", "AgentsDim" } }, {
		{ "▶ " .. running .. " running", running > 0 and "AgentsRunning" or "AgentsDim" },
		{ "   ⏸ " .. paused .. " paused ", "AgentsDim" },
	}, width))
	C.push(canvas, { { "" } })

	if #order == 0 then
		C.push(canvas, { { "  No queues. Select an agent in the hub and press ", "AgentsDim" }, { "a", "AgentsKey" }, { " here to add a prompt.", "AgentsDim" } })
	end

	for _, folder in ipairs(order) do
		local names = folders[folder]
		table.sort(names)
		local lnum = C.push(canvas, { { " ▌ ", "AgentsProject" }, { short_path(folder), "AgentsProject" } })
		view.line_map[lnum] = { name = names[1] }
		for _, name in ipairs(names) do
			local q = queues[name]
			local alive = hub.S.by_name[name] ~= nil
			local done, total = counts(q)
			local state
			if not alive then
				state = { "tab closed", "AgentsExited" }
			elseif q.running then
				state = { "▶ running", "AgentsRunning" }
			elseif q.reason and q.reason ~= "finished" then
				state = { "⏸ paused: " .. q.reason, "AgentsWaiting" }
			elseif q.reason == "finished" then
				state = { "✓ finished", "AgentsDone" }
			else
				state = { "⏸ stopped", "AgentsDim" }
			end
			lnum = C.push(canvas, C.row({
				{ "   " },
				{ q.label or name, name == (selected and selected.name) and "AgentsToolSel" or "AgentsTool" },
				{ "  " .. (q.tool or ""), "AgentsDim" },
				{ "   " },
				state,
			}, { { ("%d/%d "):format(done, total), "AgentsDim" } }, width))
			view.line_map[lnum] = { name = name }
			if #q.items == 0 then
				lnum = C.push(canvas, {
					{ "      queue empty — press ", "AgentsDim" },
					{ "a", "AgentsKey" },
					{ " to queue prompts for autopilot", "AgentsDim" },
				})
				view.line_map[lnum] = { name = name }
			end
			for i, item in ipairs(q.items) do
				local mark = STATE_MARK[item.state] or STATE_MARK.pending
				local when = ""
				if item.state == "done" and item.done_at then
					when = "done " .. C.age(os.time() - item.done_at) .. " ago"
				elseif item.state == "sent" and item.sent_at then
					when = (item.started and "working " or "sent ") .. C.age(os.time() - item.sent_at)
				end
				local text = (item.text:gsub("%s+", " "))
				lnum = C.push(canvas, C.row({
					{ "     " },
					{ mark[1] .. " ", mark[2] },
					{ i .. ". ", "AgentsDim" },
					{ C.trunc(text, width - 28), item.state == "done" and "AgentsDim" or "AgentsFile" },
				}, { { when .. " ", "AgentsDim" } }, width))
				view.line_map[lnum] = { name = name, index = i }
			end
			-- What was typed straight into the agent, for the full picture.
			local agent = hub.S.by_name[name]
			local typed = agent and require("agents.handoff").typed_prompts(agent, 5) or {}
			if #typed > 0 then
				lnum = C.push(canvas, { { "      typed in the agent (latest " .. #typed .. "):", "AgentsDim" } })
				view.line_map[lnum] = { name = name }
				for _, text in ipairs(typed) do
					lnum = C.push(canvas, {
						{ "        ↳ ", "AgentsDim" },
						{ C.trunc((text:gsub("%s+", " ")), width - 14), "Comment" },
					})
					view.line_map[lnum] = { name = name }
				end
			end
		end
		C.push(canvas, { { "" } })
	end

	C.push(canvas, {
		{ " a", "AgentsKey" },
		{ " add   ", "AgentsDim" },
		{ "A", "AgentsKey" },
		{ " add many   ", "AgentsDim" },
		{ "e", "AgentsKey" },
		{ " edit   ", "AgentsDim" },
		{ "d", "AgentsKey" },
		{ " delete   ", "AgentsDim" },
		{ "K/J", "AgentsKey" },
		{ " move   ", "AgentsDim" },
		{ "s", "AgentsKey" },
		{ " start/stop   ", "AgentsDim" },
		{ "S", "AgentsKey" },
		{ " stop all   ", "AgentsDim" },
		{ "x", "AgentsKey" },
		{ " clear done   ", "AgentsDim" },
		{ "⏎", "AgentsKey" },
		{ " open agent   ", "AgentsDim" },
		{ "q", "AgentsKey" },
		{ " close", "AgentsDim" },
	})
	C.paint(buf, canvas)
end

M.render = function()
	render()
end

local function under_cursor()
	if not (view.win and vim.api.nvim_win_is_valid(view.win)) then
		return nil
	end
	return view.line_map[vim.api.nvim_win_get_cursor(view.win)[1]]
end

-- The tab the cursor is on, else the selected agent.
local function target_name()
	local entry = under_cursor()
	if entry then
		return entry.name
	end
	local agent = hub.selected_agent()
	return agent and agent.name
end

local function add(name, texts)
	local agent = hub.S.by_name[name]
	local q = agent and queue_for(agent) or queues[name]
	if not q then
		return
	end
	for _, text in ipairs(texts) do
		text = vim.trim(text)
		if text ~= "" then
			table.insert(q.items, { text = text, state = "pending" })
		end
	end
	save()
	render()
end

-- Several prompts at once: one per line in a scratch buffer, saved with :w or q.
local function add_many(name)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "acwrite"
	vim.api.nvim_buf_set_name(buf, "autopilot://" .. name .. "/new")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
	local w, h = math.floor(vim.o.columns * 0.6), math.floor(vim.o.lines * 0.5)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		border = "rounded",
		title = " One prompt per line · :w adds them · q cancels ",
		title_pos = "center",
	})
	local function commit()
		add(name, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		vim.bo[buf].modified = false
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = buf, callback = commit })
	vim.keymap.set("n", "q", function()
		vim.bo[buf].modified = false
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })
	vim.cmd.startinsert()
end

local function map_view(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	map("a", function()
		local name = target_name()
		if not name then
			notify("Select an agent in the hub first", vim.log.levels.WARN)
			return
		end
		vim.ui.input({ prompt = "Add prompt: " }, function(text)
			if text then
				add(name, { text })
			end
		end)
	end, "Add a prompt")
	map("A", function()
		local name = target_name()
		if name then
			add_many(name)
		end
	end, "Add several prompts")
	map("e", function()
		local entry = under_cursor()
		local item = entry and entry.index and queues[entry.name].items[entry.index]
		if not item then
			return
		end
		vim.ui.input({ prompt = "Edit prompt: ", default = item.text }, function(text)
			if text and vim.trim(text) ~= "" then
				item.text = vim.trim(text)
				save()
				render()
			end
		end)
	end, "Edit prompt")
	map("d", function()
		local entry = under_cursor()
		if not entry then
			return
		end
		local q = queues[entry.name]
		if entry.index then
			if q.items[entry.index].state == "sent" and q.running then
				notify("That prompt is being worked on; stop the queue first", vim.log.levels.WARN)
				return
			end
			table.remove(q.items, entry.index)
		elseif vim.fn.confirm("Delete the whole queue of " .. (q.label or entry.name) .. "?", "&Delete\n&Cancel", 2) == 1 then
			queues[entry.name] = nil
		end
		save()
		render()
	end, "Delete prompt (or the queue, on its header)")
	local function move(delta)
		local entry = under_cursor()
		if not (entry and entry.index) then
			return
		end
		local items = queues[entry.name].items
		local to = entry.index + delta
		if to < 1 or to > #items then
			return
		end
		items[entry.index], items[to] = items[to], items[entry.index]
		save()
		render()
		for lnum, e in pairs(view.line_map) do
			if e.name == entry.name and e.index == to then
				vim.api.nvim_win_set_cursor(view.win, { lnum, 0 })
			end
		end
	end
	map("K", function()
		move(-1)
	end, "Move up")
	map("J", function()
		move(1)
	end, "Move down")
	map("s", function()
		local name = target_name()
		if name then
			M.toggle(name)
		end
	end, "Start / stop this queue")
	map("S", M.stop_all, "Stop every queue")
	map("x", function()
		local name = target_name()
		local q = name and queues[name]
		if q then
			q.items = vim.tbl_filter(function(item)
				return item.state ~= "done" and item.state ~= "skipped"
			end, q.items)
			save()
			render()
		end
	end, "Clear finished prompts")
	map("<CR>", function()
		local name = target_name()
		if name and hub.S.by_name[name] then
			M.close()
			hub.open()
			hub.select_agent(name, true)
		end
	end, "Open the agent")
	map("q", M.close, "Close")
	map("<Esc>", M.close, "Close")
end

function M.open()
	if view.win and vim.api.nvim_win_is_valid(view.win) then
		vim.api.nvim_set_current_win(view.win)
		render()
		return
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "agentqueue"
	vim.bo[buf].modifiable = false
	local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.75)
	view.buf = buf
	view.win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		border = "rounded",
		style = "minimal",
		title = " Autopilot ",
		title_pos = "center",
	})
	vim.wo[view.win].cursorline = true
	map_view(buf)
	render()
	-- Start on the selected agent's block.
	local agent = hub.selected_agent()
	for lnum, entry in pairs(view.line_map) do
		if agent and entry.name == agent.name and not entry.index then
			pcall(vim.api.nvim_win_set_cursor, view.win, { lnum, 0 })
		end
	end
end

function M.close()
	if view.win and vim.api.nvim_win_is_valid(view.win) then
		vim.api.nvim_win_close(view.win, true)
	end
	view.win, view.buf = nil, nil
end

function M.setup(api)
	hub = api
	load()
	-- Queues left running by an earlier Neovim keep going from their state.
end

return M
