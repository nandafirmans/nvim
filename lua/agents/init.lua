-- Agent hub: a tab with an agent sidebar, the selected agent's terminal and
-- the code it changed. Agents run in tmux (see agents.tmux) so they outlive
-- Neovim; Claude Code reports its state through hooks in ~/.claude/settings.json.
local tmux = require("agents.tmux")
local git = require("agents.git")
local office = require("agents.office")

local M = {}

local config = {
	roots = { "~/_dev" },
	scan_depth = 3,
	tools = { "claude", "omp", "opencode", "codex", "pi" },
	sidebar_width = 34,
	changes_width = 46,
	-- Fallback for agents without hooks: output within this many seconds counts as running.
	active_seconds = 3,
}

local SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local TICK_MS = 125
local POLL_EVERY = 8 -- ticks between tmux polls (~1s)
local GIT_EVERY = 24 -- ticks between git refreshes (~3s)

local STATUS = {
	running = { label = "running", hl = "AgentsRunning" },
	waiting = { icon = "\u{f0f3}", label = "needs input", hl = "AgentsWaiting" },
	done = { icon = "\u{f00c}", label = "done", hl = "AgentsDone" },
	idle = { icon = "\u{f10c}", label = "idle", hl = "AgentsIdle" },
	exited = { icon = "\u{f00d}", label = "exited", hl = "AgentsExited" },
}
local BRANCH_ICON = "\u{e0a0}"

local S = {
	agents = {}, -- sorted list from tmux
	by_name = {},
	meta = {}, -- name -> { status, since }
	selected = nil,
	term_bufs = {}, -- name -> terminal buffer attached to the tmux session
	changes = {}, -- cwd -> git.changes() result
	git_busy = {},
	tab = nil,
	wins = {},
	bufs = {},
	list_map = {}, -- sidebar line (1-based) -> agent name
	change_map = {}, -- changes line (1-based) -> file entry
	tick = 0,
	timer = nil,
	view = "term", -- center pane: "term" (selected agent) or "office"
	tails = {}, -- name -> last screen line, for tabs without hooks
	office_rects = {},
}

-- Rendering helpers -----------------------------------------------------------

local C = require("agents.canvas")
local width, trunc, trunc_left, seg_width, row = C.width, C.trunc, C.trunc_left, C.seg_width, C.row
local new_canvas, push, paint, age, diffstat = C.new_canvas, C.push, C.paint, C.age, C.diffstat

-- State -----------------------------------------------------------------------

local function valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function hub_open()
	return S.tab
		and vim.api.nvim_tabpage_is_valid(S.tab)
		and valid_win(S.wins.list)
		and valid_win(S.wins.term)
		and valid_win(S.wins.changes)
end

local function compute_status(agent)
	if agent.dead then
		return "exited"
	end
	if STATUS[agent.hook] then
		return agent.hook
	end
	if os.time() - agent.activity <= config.active_seconds then
		return "running"
	end
	return "idle"
end

local function status_of(name)
	local meta = S.meta[name]
	return meta and meta.status or "idle"
end

local function selected_agent()
	return S.selected and S.by_name[S.selected]
end

-- The name a tab shows: its rename, else the tool and its number in the desk.
local function display_name(agent)
	return agent.label or (agent.tool .. " #" .. agent.index)
end

local function agent_label(agent)
	return agent.project .. " · " .. display_name(agent)
end

local function notify_transition(agent, before, after)
	local viewing = vim.api.nvim_get_current_win() == S.wins.term and S.selected == agent.name
	if viewing or before == after then
		return
	end
	if after == "waiting" then
		vim.notify(agent_label(agent) .. " needs input", vim.log.levels.WARN, { title = "Agents" })
	elseif before == "running" and after == "done" then
		vim.notify(agent_label(agent) .. " is done", vim.log.levels.INFO, { title = "Agents" })
	elseif after == "exited" then
		vim.notify(agent_label(agent) .. " exited", vim.log.levels.WARN, { title = "Agents" })
	end
end

-- Sidebar ---------------------------------------------------------------------

local function render_list()
	if not hub_open() then
		return
	end
	local total = config.sidebar_width
	local canvas = new_canvas()
	S.list_map = {}

	push(canvas, row({ { " AGENTS", "AgentsTitle" } }, { { tostring(#S.agents) .. " ", "AgentsDim" } }, total))
	push(canvas, { { "" } })

	if #S.agents == 0 then
		push(canvas, { { "  No agents running.", "AgentsDim" } })
		push(canvas, { { "  Press ", "AgentsDim" }, { "n", "AgentsKey" }, { " to start one.", "AgentsDim" } })
	end

	local frame = SPINNER[(S.tick % #SPINNER) + 1]

	-- Desk headers roll up their tabs, so a busy desk shows even when scrolled past.
	local rollup = {}
	for _, agent in ipairs(S.agents) do
		local counts = rollup[agent.project] or { running = 0, waiting = 0 }
		rollup[agent.project] = counts
		local status = status_of(agent.name)
		if counts[status] then
			counts[status] = counts[status] + 1
		end
	end

	local project
	for _, agent in ipairs(S.agents) do
		if agent.project ~= project then
			if project then
				push(canvas, { { "" } })
			end
			project = agent.project
			local counts = rollup[project]
			local right = {}
			if counts.waiting > 0 then
				vim.list_extend(right, { { STATUS.waiting.icon .. " " .. counts.waiting, STATUS.waiting.hl }, { " " } })
			end
			if counts.running > 0 then
				vim.list_extend(right, { { frame .. " " .. counts.running, STATUS.running.hl }, { " " } })
			end
			push(canvas, row({ { "  ▾ ", "AgentsDim" }, { trunc(project, total - 14), "AgentsProject" } }, right, total))
		end

		local status = status_of(agent.name)
		local spec = STATUS[status]
		local is_selected = agent.name == S.selected
		local line_hl = is_selected and "AgentsSel" or nil
		local changes = S.changes[agent.cwd]
		local stat = changes and diffstat(changes.add, changes.del) or {}
		local bar = is_selected and { "▎", "AgentsBar" } or { " " }
		local jump = S.jump_labels and S.jump_labels[agent.name]
		local name_hl = is_selected and "AgentsToolSel" or "AgentsTool"
		local name_segs = agent.label and { { trunc(agent.label, total - 16), name_hl } }
			or { { agent.tool, name_hl }, { " #" .. agent.index, "AgentsDim" } }

		local first = push(
			canvas,
			row(
				vim.list_extend({
					bar,
					jump and { jump, "AgentsJump" } or { " " },
					{ " " },
					{ spec.icon or frame, spec.hl },
					{ " " },
				}, name_segs),
				vim.list_extend(stat, { { " " } }),
				total
			),
			line_hl
		)

		local since = S.meta[agent.name] and S.meta[agent.name].since or os.time()
		local label = spec.label
		if status ~= "running" then
			label = label .. " " .. age(os.time() - since)
		end
		local branch = changes and changes.branch or agent.branch
		local detail = { bar, { "    " }, { label, spec.hl } }
		-- While working (or asking), what it does says more than the branch.
		local doing = (status == "running" or status == "waiting")
			and (agent.activity_text or S.tails[agent.name])
		local room = total - seg_width(detail) - 4
		if doing then
			table.insert(detail, { " · " .. trunc(doing, room - 1), "AgentsDim" })
		elseif branch then
			table.insert(detail, { "  " .. BRANCH_ICON .. " " .. trunc(branch, room - 1), "AgentsDim" })
		end
		local second = push(canvas, detail, line_hl)

		S.list_map[first] = agent.name
		S.list_map[second] = agent.name
	end

	push(canvas, { { "" } })
	local keys = {
		{ { "n", "desk" }, { "t", "tab" }, { "r", "rename" } },
		{ { "x", "kill" }, { "R", "restart" }, { "D", "diff" } },
		{ { "⏎", "focus" }, { "^␣", "jump" }, { "O", "office" } },
		{ { "b", "browser" }, { "g", "lazygit" } },
	}
	for _, line in ipairs(keys) do
		local segs = { { " " } }
		for _, key in ipairs(line) do
			vim.list_extend(segs, { { key[1], "AgentsKey" }, { " " .. key[2] .. "   ", "AgentsDim" } })
		end
		push(canvas, segs)
	end

	paint(S.bufs.list, canvas)

	-- Keep the cursor on the selected agent so the highlight and cursor agree.
	if vim.api.nvim_get_current_win() ~= S.wins.list then
		for lnum, name in pairs(S.list_map) do
			if name == S.selected and (S.list_map[lnum - 1] ~= name) then
				pcall(vim.api.nvim_win_set_cursor, S.wins.list, { lnum, 0 })
				break
			end
		end
	end
end

-- Changes panel ---------------------------------------------------------------

-- Untracked files read as U (as in VS Code); merge conflicts as !.
local KIND_LABEL = { ["?"] = "U", U = "!" }
local KIND_HL = { M = "AgentsChange", A = "AgentsAdd", ["?"] = "AgentsAdd", D = "AgentsDel", R = "AgentsChange", U = "AgentsWaiting" }

local function render_changes()
	if not hub_open() then
		return
	end
	local total = config.changes_width
	local canvas = new_canvas()
	S.change_map = {}
	local agent = selected_agent()
	local info = agent and S.changes[agent.cwd]

	push(canvas, row({ { " CHANGES", "AgentsTitle" } }, {
		{ info and (#info.files .. (#info.files == 1 and " file " or " files ")) or "", "AgentsDim" },
	}, total))

	if not agent then
		push(canvas, { { "" } })
		push(canvas, { { "  No agent selected.", "AgentsDim" } })
	elseif not info then
		push(canvas, { { "" } })
		push(canvas, { { "  " .. trunc(vim.fn.fnamemodify(agent.cwd, ":~"), total - 3), "AgentsDim" } })
		push(canvas, { { "  Loading, or not a git repository.", "AgentsDim" } })
	else
		push(
			canvas,
			row(
				{ { " " .. BRANCH_ICON .. " ", "AgentsDim" }, { trunc(info.branch or "detached", total - 18), "AgentsProject" } },
				vim.list_extend(diffstat(info.add, info.del), { { " " } }),
				total
			)
		)
		push(canvas, { { " " .. trunc_left(vim.fn.fnamemodify(agent.cwd, ":~"), total - 2), "AgentsDim" } })
		push(canvas, { { "" } })
		if #info.files == 0 then
			push(canvas, { { "  Working tree clean.", "AgentsDim" } })
		end
		for _, entry in ipairs(info.files) do
			local stat = entry.binary and { { "bin", "AgentsDim" } } or diffstat(entry.add, entry.del)
			table.insert(stat, { " " })
			local name = vim.fs.basename(entry.path)
			local dir = vim.fs.dirname(entry.path)
			local left = {
				{ " " },
				{ KIND_LABEL[entry.kind] or entry.kind, KIND_HL[entry.kind] },
				{ " " },
				{ trunc(name, total - seg_width(stat) - 6), entry.kind == "D" and "AgentsDim" or "AgentsFile" },
			}
			local room = total - seg_width(left) - seg_width(stat) - 2
			if dir ~= "." and room > 4 then
				table.insert(left, { " " .. trunc_left(dir, room), "AgentsDim" })
			end
			local lnum = push(canvas, row(left, stat, total))
			S.change_map[lnum] = entry
		end
	end

	push(canvas, { { "" } })
	push(canvas, {
		{ " ⏎", "AgentsKey" },
		{ " preview   ", "AgentsDim" },
		{ "o", "AgentsKey" },
		{ " open   ", "AgentsDim" },
		{ "D", "AgentsKey" },
		{ " diffview   ", "AgentsDim" },
		{ "g", "AgentsKey" },
		{ " lazygit", "AgentsDim" },
	})

	paint(S.bufs.changes, canvas)
end

-- Terminal pane ---------------------------------------------------------------

local function office_buf()
	local buf = S.bufs.office
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].filetype = "agentoffice"
	vim.bo[buf].modifiable = false
	S.bufs.office = buf
	M._map_office(buf)
	return buf
end

local function office_visible()
	return hub_open() and S.view == "office" and vim.api.nvim_win_get_buf(S.wins.term) == S.bufs.office
end

local function render_office()
	if not office_visible() then
		return
	end
	local canvas, rects = office.render(S.agents, vim.api.nvim_win_get_width(S.wins.term), {
		STATUS = STATUS,
		status_of = status_of,
		since = function(name)
			return S.meta[name] and S.meta[name].since or os.time()
		end,
		display_name = display_name,
		changes_of = function(agent)
			return S.changes[agent.cwd]
		end,
		selected = S.selected,
		jump_labels = S.jump_labels,
		tails = S.tails,
		tick = S.tick,
	})
	S.office_rects = rects
	paint(S.bufs.office, canvas)
end

local function update_winbar()
	if not hub_open() then
		return
	end
	if S.view == "office" then
		vim.wo[S.wins.term].winbar = "%#AgentsTitle#  Agent Office %#AgentsDim#  ⏎ sit with agent   O terminal   b browser   ^␣ jump"
		return
	end
	local agent = selected_agent()
	if not agent then
		vim.wo[S.wins.term].winbar = "%#AgentsDim#  no agent selected"
		return
	end
	local spec = STATUS[status_of(agent.name)]
	local changes = S.changes[agent.cwd]
	local branch = changes and changes.branch or agent.branch
	local function esc(text)
		return (tostring(text):gsub("%%", "%%%%"))
	end
	local parts = {
		"%#AgentsToolSel# ",
		esc(display_name(agent)),
		" %#AgentsDim# ",
		esc(agent.project),
	}
	if branch then
		vim.list_extend(parts, { "  ", BRANCH_ICON, " ", esc(branch) })
	end
	vim.list_extend(parts, { "%=%#", spec.hl, "#", spec.label, " " })
	vim.wo[S.wins.term].winbar = table.concat(parts)
end

local function set_term_win_options(win)
	local wo = vim.wo[win]
	wo.wrap = false
	wo.number = false
	wo.relativenumber = false
	wo.signcolumn = "no"
	wo.foldcolumn = "0"
	wo.statuscolumn = ""
	wo.cursorline = false
	wo.spell = false
end

local function empty_buf()
	local buf = S.bufs.empty
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].filetype = "agentempty"
	local canvas = new_canvas()
	for _ = 1, 4 do
		push(canvas, { { "" } })
	end
	push(canvas, { { "    No agent selected", "AgentsTitle" } })
	push(canvas, { { "" } })
	push(canvas, { { "    Press ", "AgentsDim" }, { "n", "AgentsKey" }, { " in the sidebar to start an agent,", "AgentsDim" } })
	push(canvas, { { "    or pick one with ", "AgentsDim" }, { "j", "AgentsKey" }, { "/", "AgentsDim" }, { "k", "AgentsKey" }, { ".", "AgentsDim" } })
	paint(buf, canvas)
	S.bufs.empty = buf
	return buf
end

local show_agent

local function on_term_exit(name, buf, started)
	vim.schedule(function()
		if S.term_bufs[name] == buf then
			S.term_bufs[name] = nil
		end
		local displayed = hub_open() and vim.api.nvim_win_get_buf(S.wins.term) == buf
		-- A detach (prefix d) ends the attach client but not the agent: reattach.
		-- Skip when the attach died at once, so a broken session cannot loop.
		local alive = tmux.run_sync({ "has-session", "-t", "=" .. name }).code == 0
		if displayed and alive and S.selected == name and os.time() - started > 1 then
			show_agent(name, false)
		elseif displayed then
			vim.api.nvim_win_set_buf(S.wins.term, empty_buf())
		end
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end)
end

show_agent = function(name, focus)
	if not hub_open() then
		return
	end
	local win = S.wins.term
	if S.view == "office" and not focus then
		if vim.api.nvim_win_get_buf(win) ~= office_buf() then
			vim.api.nvim_win_set_buf(win, S.bufs.office)
			set_term_win_options(win)
		end
		update_winbar()
		render_office()
		return
	end
	S.view = "term"
	if not name or not S.by_name[name] then
		vim.api.nvim_win_set_buf(win, empty_buf())
		update_winbar()
		return
	end
	local buf = S.term_bufs[name]
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_win_set_buf(win, buf)
	else
		buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_win_set_buf(win, buf)
		local started = os.time()
		vim.api.nvim_win_call(win, function()
			vim.fn.jobstart(tmux.attach_cmd(name), {
				term = true,
				on_exit = function()
					on_term_exit(name, buf, started)
				end,
			})
		end)
		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].buflisted = false
		vim.bo[buf].filetype = "agentterm"
		vim.b[buf].agent_name = name
		-- Esc stays with the agent (it interrupts Claude); Ctrl-Space is the one hub key.
		for _, lhs in ipairs({ "<C-Space>", "<C-@>" }) do
			vim.keymap.set("t", lhs, M.jump, { buffer = buf, desc = "Jump to tab" })
		end
		-- Typing should reach the agent as soon as its pane is entered.
		vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
			buffer = buf,
			callback = function()
				vim.schedule(function()
					if vim.api.nvim_get_current_buf() == buf and vim.bo[buf].buftype == "terminal" then
						vim.cmd.startinsert()
					end
				end)
			end,
		})
		S.term_bufs[name] = buf
	end
	set_term_win_options(win)
	update_winbar()
	if focus then
		vim.api.nvim_set_current_win(win)
		vim.cmd.startinsert()
	end
end

local function select_agent(name, focus)
	local changed = name ~= S.selected
	S.selected = name
	if changed or focus then
		show_agent(name, focus)
	end
	render_list()
	render_changes()
	render_office()
end

-- Polling ---------------------------------------------------------------------

local refresh_changes

local function apply_agents(list)
	table.sort(list, function(a, b)
		if a.project ~= b.project then
			return a.project < b.project
		end
		return a.index < b.index
	end)
	S.agents = list
	S.by_name = {}
	for _, agent in ipairs(list) do
		S.by_name[agent.name] = agent
		local status = compute_status(agent)
		local meta = S.meta[agent.name]
		if not meta then
			S.meta[agent.name] = { status = status, since = os.time() }
		elseif meta.status ~= status then
			notify_transition(agent, meta.status, status)
			meta.status, meta.since = status, os.time()
		end
	end
	for name, buf in pairs(S.term_bufs) do
		if not S.by_name[name] then
			S.term_bufs[name] = nil
			if vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
	end
	if S.selected and not S.by_name[S.selected] then
		S.selected = nil
	end
	if not S.selected and list[1] then
		S.selected = list[1].name
	end
end

local function poll(cb)
	tmux.list(function(list)
		local before = S.selected
		apply_agents(list)
		if hub_open() then
			local shown = vim.b[vim.api.nvim_win_get_buf(S.wins.term)].agent_name
			if S.selected ~= before or shown ~= S.selected then
				show_agent(S.selected, false)
			end
			render_list()
			render_changes()
			update_winbar()
			render_office()
			do
				-- Tabs without hooks speak through the last line on their screen.
				for _, agent in ipairs(S.agents) do
					if not agent.activity_text and status_of(agent.name) == "running" then
						tmux.last_line(agent.name, function(line)
							S.tails[agent.name] = line
						end)
					end
				end
			end
		end
		if cb then
			cb()
		end
	end)
end

refresh_changes = function()
	local seen = {}
	for _, agent in ipairs(S.agents) do
		local cwd = agent.cwd
		if cwd ~= "" and not seen[cwd] and not S.git_busy[cwd] then
			seen[cwd] = true
			S.git_busy[cwd] = true
			git.changes(cwd, function(info)
				S.git_busy[cwd] = nil
				S.changes[cwd] = info
				render_list()
				local agent_now = selected_agent()
				if agent_now and agent_now.cwd == cwd then
					render_changes()
					update_winbar()
				end
			end)
		end
	end
end

local function stop_timer()
	if S.timer then
		S.timer:stop()
		S.timer:close()
		S.timer = nil
	end
end

local function on_tick()
	S.tick = S.tick + 1
	if S.tick % POLL_EVERY == 0 then
		poll(function()
			if #S.agents == 0 and not hub_open() then
				stop_timer()
			end
		end)
	elseif hub_open() then
		for _, agent in ipairs(S.agents) do
			if status_of(agent.name) == "running" then
				render_list()
				if S.tick % 2 == 0 then
					render_office()
				end
				break
			end
		end
	end
	if S.tick % GIT_EVERY == 0 and hub_open() then
		refresh_changes()
	end
end

local function start_timer()
	if S.timer then
		return
	end
	S.timer = vim.uv.new_timer()
	S.timer:start(TICK_MS, TICK_MS, vim.schedule_wrap(on_tick))
end

-- Actions ---------------------------------------------------------------------

local function find_projects()
	local out, seen = {}, {}
	local function add(path)
		path = vim.fs.normalize(path)
		if not seen[path] then
			seen[path] = true
			table.insert(out, path)
		end
	end

	local here = git.root(vim.api.nvim_buf_get_name(0)) or git.root(vim.fn.getcwd())
	if here then
		add(here)
	end

	local scanned = {}
	local function scan(dir, depth)
		for name, kind in vim.fs.dir(dir) do
			if kind == "directory" and name:sub(1, 1) ~= "." and name ~= "node_modules" and not name:match("%.worktrees$") then
				local path = vim.fs.joinpath(dir, name)
				if vim.uv.fs_stat(path .. "/.git") then
					table.insert(scanned, path)
				elseif depth < config.scan_depth then
					scan(path, depth + 1)
				end
			end
		end
	end
	for _, root in ipairs(config.roots) do
		local dir = vim.fs.normalize(root)
		if vim.uv.fs_stat(dir) then
			scan(dir, 1)
		end
	end
	table.sort(scanned)
	for _, path in ipairs(scanned) do
		add(path)
	end
	return out
end

local function next_index(project)
	local max = 0
	for _, agent in ipairs(S.agents) do
		if agent.project == project then
			max = math.max(max, agent.index)
		end
	end
	return max + 1
end

local function current_branch(cwd)
	local result = vim.system({ "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }):wait()
	return result.code == 0 and vim.trim(result.stdout) or nil
end

-- Starts one tab (a tmux session) in a desk. spec: project, cwd, tool, command, branch.
local function create_agent(spec)
	local index = next_index(spec.project)
	local slug = spec.project:gsub("[^%w_-]", "-")
	local name = slug .. "-" .. index
	while tmux.run_sync({ "has-session", "-t", "=" .. name }).code == 0 do
		index = index + 1
		name = slug .. "-" .. index
	end

	local ok, err = tmux.new_session({
		name = name,
		cwd = spec.cwd,
		command = spec.command,
		options = {
			project = spec.project,
			tool = spec.tool,
			index = index,
			cwd = spec.cwd,
			branch = spec.branch or current_branch(spec.cwd) or "",
		},
	})
	if not ok then
		vim.notify("Could not start " .. spec.tool .. ": " .. err, vim.log.levels.ERROR, { title = "Agents" })
		return
	end

	S.selected = name
	M.open()
	start_timer()
	poll(function()
		refresh_changes()
		select_agent(name, true)
	end)
end

-- Fuzzy picker for the new-agent flow. Uses telescope when it is installed,
-- since this config has no vim.ui.select provider; falls back otherwise.
local function pick(items, opts, cb)
	local ok = pcall(require, "telescope")
	if not ok then
		vim.ui.select(items, { prompt = opts.prompt, format_item = opts.format }, cb)
		return
	end
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local format = opts.format or tostring
	require("telescope.pickers")
		.new(require("telescope.themes").get_dropdown({ previewer = false }), {
			prompt_title = opts.prompt,
			finder = require("telescope.finders").new_table({
				results = items,
				entry_maker = function(item)
					local text = format(item)
					return { value = item, display = text, ordinal = text }
				end,
			}),
			sorter = require("telescope.config").values.generic_sorter({}),
			attach_mappings = function(prompt_buf)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_buf)
					if entry then
						-- Let telescope finish closing before the next prompt opens.
						vim.schedule(function()
							cb(entry.value)
						end)
					end
				end)
				return true
			end,
		})
		:find()
end

local SHELL_TAB = "shell"
local CUSTOM_TAB = "custom command…"

-- Asks what a tab runs: an agent CLI, a plain shell, or any command
-- (a dev server, tests in watch mode). cb(tool, command).
local function choose_command(with_extras, cb)
	local items = vim.tbl_filter(function(tool)
		return vim.fn.executable(tool) == 1
	end, config.tools)
	if with_extras then
		vim.list_extend(items, { SHELL_TAB, CUSTOM_TAB })
	end
	if #items == 0 then
		vim.notify("No agent CLI found on PATH", vim.log.levels.ERROR, { title = "Agents" })
		return
	end
	pick(items, { prompt = "Run" }, function(choice)
		if choice == SHELL_TAB then
			local shell = vim.o.shell
			cb(vim.fs.basename(shell), shell)
		elseif choice == CUSTOM_TAB then
			vim.ui.input({ prompt = "Command: " }, function(command)
				command = command and vim.trim(command) or ""
				if command ~= "" then
					cb(command:match("^(%S+)"), command)
				end
			end)
		elseif choice then
			cb(choice, choice)
		end
	end)
end

local OTHER_FOLDER = "Other or new folder…"

-- New desk: pick a project, an agent and optionally a worktree branch.
function M.new_agent()
	local function start_in(root)
		choose_command(true, function(tool, command)
			vim.ui.input({ prompt = "Worktree branch (empty = work in the repo): " }, function(branch)
				if branch == nil then
					return
				end
				branch = vim.trim(branch)
				local cwd = root
				if branch ~= "" then
					local path, err = git.add_worktree(root, branch)
					if not path then
						vim.notify("git worktree add failed: " .. err, vim.log.levels.ERROR, { title = "Agents" })
						return
					end
					cwd = path
				end
				create_agent({
					project = vim.fs.basename(root),
					cwd = cwd,
					tool = tool,
					command = command,
					branch = branch ~= "" and branch or nil,
				})
			end)
		end)
	end

	local projects = find_projects()
	table.insert(projects, OTHER_FOLDER)
	pick(projects, {
		prompt = "Project",
		format = function(path)
			return path == OTHER_FOLDER and "  " .. OTHER_FOLDER or vim.fn.fnamemodify(path, ":~")
		end,
	}, function(choice)
		if choice ~= OTHER_FOLDER then
			start_in(choice)
			return
		end
		-- Any folder, also outside config.roots or not created yet; <Tab> completes.
		vim.ui.input({ prompt = "Folder: ", default = vim.fn.fnamemodify(vim.fn.getcwd(), ":~") .. "/", completion = "dir" }, function(path)
			if not path or vim.trim(path) == "" then
				return
			end
			path = vim.fs.normalize(vim.fn.expand(vim.trim(path)))
			if vim.fn.isdirectory(path) == 0 then
				-- A new project: create the folder, and a repo so the changes panel works.
				local choice = vim.fn.confirm(
					"Create " .. vim.fn.fnamemodify(path, ":~") .. "?",
					"&Create + git init\nCreate &only\n&Cancel",
					1
				)
				if choice == 0 or choice == 3 then
					return
				end
				vim.fn.mkdir(path, "p")
				if choice == 1 then
					local result = vim.system({ "git", "init", "-q", path }, { text = true }):wait()
					if result.code ~= 0 then
						vim.notify("git init failed: " .. vim.trim(result.stderr or ""), vim.log.levels.WARN, { title = "Agents" })
					end
				end
				start_in(path)
				return
			end
			start_in(git.root(path) or path)
		end)
	end)
end

-- New tab in the selected desk, in the same directory (and worktree) as the selected tab.
function M.new_tab()
	local agent = selected_agent()
	if not agent then
		M.new_agent()
		return
	end
	choose_command(true, function(tool, command)
		create_agent({ project = agent.project, cwd = agent.cwd, tool = tool, command = command })
	end)
end

function M.rename(name)
	local agent = S.by_name[name or S.selected]
	if not agent then
		return
	end
	vim.ui.input({ prompt = "Rename tab: ", default = agent.label or "" }, function(label)
		if label == nil then
			return
		end
		tmux.set_option(agent.name, "label", vim.trim(label))
		poll()
	end)
end

local JUMP_KEYS = "asdfghjklqwertyuiopzxcvbnm"

-- Jump mode: every tab gets a letter; one key press focuses that tab.
function M.jump()
	M.open()
	if #S.agents == 0 then
		return
	end
	S.jump_labels = {}
	local by_key = {}
	for i, agent in ipairs(S.agents) do
		local key = JUMP_KEYS:sub(i, i)
		if key == "" then
			break
		end
		S.jump_labels[agent.name] = key
		by_key[key] = agent.name
	end
	render_list()
	render_office()
	vim.cmd.redraw()
	local ok, key = pcall(vim.fn.getcharstr)
	S.jump_labels = nil
	render_list()
	render_office()
	local name = ok and by_key[key]
	if name then
		select_agent(name, true)
	end
end

local function list_agent_under_cursor()
	if not valid_win(S.wins.list) then
		return nil
	end
	return S.list_map[vim.api.nvim_win_get_cursor(S.wins.list)[1]]
end

function M.kill_agent(name)
	name = name or S.selected
	local agent = name and S.by_name[name]
	if not agent then
		return
	end
	if vim.fn.confirm("Kill " .. agent_label(agent) .. "?", "&Yes\n&No", 2) ~= 1 then
		return
	end
	tmux.kill(name)
	S.meta[name] = nil
	poll(refresh_changes)
end

function M.restart_agent(name)
	name = name or S.selected
	if not (name and S.by_name[name]) then
		return
	end
	tmux.respawn(name)
	poll()
end

local function load_diffview()
	local ok, lazy = pcall(require, "lazy")
	if ok then
		lazy.load({ plugins = { "diffview.nvim" } })
	end
end

function M.diffview(path)
	local agent = selected_agent()
	if not agent then
		return
	end
	load_diffview()
	local cmd = "DiffviewOpen -C" .. vim.fn.fnameescape(agent.cwd)
	if path then
		cmd = cmd .. " -- " .. vim.fn.fnameescape(path)
	end
	vim.cmd(cmd)
end

local function preview_change(entry)
	local agent = selected_agent()
	if not (agent and entry) then
		return
	end
	git.diff(agent.cwd, entry, function(lines)
		if #lines == 0 then
			lines = { "No textual diff (binary or unchanged)." }
		end
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].filetype = "diff"
		vim.bo[buf].modifiable = false
		vim.bo[buf].bufhidden = "wipe"
		local w = math.floor(vim.o.columns * 0.8)
		local h = math.floor(vim.o.lines * 0.8)
		local win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = w,
			height = h,
			row = math.floor((vim.o.lines - h) / 2),
			col = math.floor((vim.o.columns - w) / 2),
			border = "rounded",
			style = "minimal",
			title = " " .. entry.path .. " ",
			title_pos = "center",
			footer = " q close   o open file   D diffview ",
			footer_pos = "center",
		})
		local function close()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end
		local opts = { buffer = buf, nowait = true }
		vim.keymap.set("n", "q", close, opts)
		vim.keymap.set("n", "<Esc>", close, opts)
		vim.keymap.set("n", "o", function()
			close()
			vim.cmd("tabedit " .. vim.fn.fnameescape(agent.cwd .. "/" .. entry.path))
		end, opts)
		vim.keymap.set("n", "D", function()
			close()
			M.diffview(entry.path)
		end, opts)
	end)
end

local function change_under_cursor()
	return S.change_map[vim.api.nvim_win_get_cursor(0)[1]]
end

-- Sends a file reference (and line range) to the selected agent's prompt.
function M.send(opts)
	local agent = selected_agent()
	if not agent then
		vim.notify("No agent selected", vim.log.levels.WARN, { title = "Agents" })
		return
	end
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		return
	end
	local ref = "@" .. (vim.fs.relpath(agent.cwd, file) or file)
	if opts and opts.range and opts.range > 0 then
		ref = ref .. "#L" .. opts.line1 .. "-" .. opts.line2
	end
	tmux.paste(agent.name, ref .. " ")
	vim.notify("Sent " .. ref .. " to " .. agent_label(agent), vim.log.levels.INFO, { title = "Agents" })
end

-- Opens lazygit in a float, in the selected agent's repo (or worktree).
function M.lazygit()
	local agent = selected_agent()
	if not agent then
		vim.notify("No agent selected", vim.log.levels.WARN, { title = "Agents" })
		return
	end
	if vim.fn.executable("lazygit") == 0 then
		vim.notify("lazygit is not installed (brew install lazygit)", vim.log.levels.ERROR, { title = "Agents" })
		return
	end
	local ok, toggleterm = pcall(require, "toggleterm.terminal")
	if not ok then
		vim.notify("toggleterm.nvim is needed for the lazygit float", vim.log.levels.ERROR, { title = "Agents" })
		return
	end
	toggleterm.Terminal
		:new({
			cmd = "lazygit",
			dir = agent.cwd,
			direction = "float",
			close_on_exit = true,
			hidden = true,
			on_exit = function()
				-- Commits and stashes change what the panel should show.
				vim.schedule(refresh_changes)
			end,
		})
		:toggle()
end

-- Browser ---------------------------------------------------------------------

-- Finds the newest local dev-server URL printed in the selected desk's tabs.
local function detect_url()
	local agent = selected_agent()
	if not agent then
		return nil
	end
	local found
	for _, tab in ipairs(S.agents) do
		if tab.project == agent.project then
			local screen = tmux.run_sync({ "capture-pane", "-p", "-J", "-S", "-300", "-t", "=" .. tab.name .. ":" }).stdout or ""
			for url in screen:gmatch("https?://[%w%.%-]*:%d+[%w%./%-_?=&#]*") do
				if url:match("localhost") or url:match("127%.0%.0%.1") or url:match("0%.0%.0%.0") then
					found = url:gsub("0%.0%.0%.0", "localhost")
				end
			end
		end
	end
	return found
end

-- terminal-browser's own process. Its WezTerm pane runs only this command,
-- so ending the process also closes the pane; no `wezterm cli` round trip
-- (which can hang) is needed.
local BROWSER_PROCESS = "terminal-browser.app/Contents/MacOS/terminal-browser"

-- Closes any running terminal-browser; returns whether one was running.
local function close_browser()
	local running = vim.system({ "pgrep", "-f", BROWSER_PROCESS }):wait(2000).code == 0
	if running then
		vim.system({ "pkill", "-TERM", "-f", BROWSER_PROCESS }):wait(2000)
	end
	return running
end

-- Toggles terminal-browser next to Neovim. Neovim's :terminal cannot show
-- kitty graphics, so the browser gets its own WezTerm pane instead.
function M.browser()
	-- `b` toggles: a running browser is closed instead of opening another.
	if close_browser() then
		S.browser_opened = false
		return
	end
	if vim.fn.executable("terminal-browser") == 0 then
		vim.notify("terminal-browser is not installed (brew install --cask terminal-browser)", vim.log.levels.ERROR, { title = "Agents" })
		return
	end
	vim.ui.input({ prompt = "Open URL: ", default = detect_url() or "http://localhost:3000" }, function(url)
		url = url and vim.trim(url) or ""
		if url == "" then
			return
		end
		local cmd
		if vim.env.WEZTERM_PANE and vim.fn.executable("wezterm") == 1 then
			cmd = { "wezterm", "cli", "split-pane", "--right", "--percent", "45", "--pane-id", vim.env.WEZTERM_PANE, "--", "terminal-browser", "open", url }
		elseif vim.fn.executable("wezterm") == 1 then
			cmd = { "wezterm", "start", "--", "terminal-browser", "open", url }
		else
			vim.notify("Needs WezTerm (or another kitty-graphics terminal) to show pages", vim.log.levels.ERROR, { title = "Agents" })
			return
		end
		S.browser_opened = true
		vim.system(cmd, { text = true }, function(result)
			vim.schedule(function()
				if result.code ~= 0 then
					vim.notify("Could not open browser: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR, { title = "Agents" })
				end
			end)
		end)
	end)
end

-- Layout ----------------------------------------------------------------------

local function panel_buf(key, filetype)
	local buf = S.bufs[key]
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = filetype
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].modifiable = false
	S.bufs[key] = buf
	return buf
end

local function set_panel_win_options(win, panel_width)
	local wo = vim.wo[win]
	wo.number = false
	wo.relativenumber = false
	wo.signcolumn = "no"
	wo.foldcolumn = "0"
	wo.statuscolumn = ""
	wo.cursorline = false
	wo.wrap = false
	wo.spell = false
	wo.list = false
	wo.winfixwidth = true
	wo.fillchars = "eob: "
	wo.winbar = ""
	wo.winhighlight = "Normal:AgentsPanel,NormalNC:AgentsPanel,EndOfBuffer:AgentsPanel,SignColumn:AgentsPanel"
	vim.api.nvim_win_set_width(win, panel_width)
end

local function map_list(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	local function step(delta)
		if #S.agents == 0 then
			return
		end
		local index = 1
		for i, agent in ipairs(S.agents) do
			if agent.name == S.selected then
				index = i
			end
		end
		index = ((index - 1 + delta) % #S.agents) + 1
		select_agent(S.agents[index].name, false)
		for lnum, name in pairs(S.list_map) do
			if name == S.selected and S.list_map[lnum - 1] ~= name then
				vim.api.nvim_win_set_cursor(0, { lnum, 0 })
			end
		end
	end
	map("j", function()
		step(1)
	end, "Next agent")
	map("k", function()
		step(-1)
	end, "Previous agent")
	map("<CR>", function()
		select_agent(list_agent_under_cursor() or S.selected, true)
	end, "Focus agent")
	map("n", M.new_agent, "New desk")
	map("t", M.new_tab, "New tab in desk")
	map("r", function()
		M.rename(list_agent_under_cursor())
	end, "Rename tab")
	map("<C-Space>", M.jump, "Jump to tab")
	map("O", M.office, "Toggle office view")
	map("b", M.browser, "Open the web result in terminal-browser")
	map("g", M.lazygit, "Lazygit in this agent's repo")
	for i = 1, 9 do
		map(tostring(i), function()
			if S.agents[i] then
				select_agent(S.agents[i].name, true)
			end
		end, "Focus tab " .. i)
	end
	map("x", function()
		M.kill_agent(list_agent_under_cursor())
	end, "Kill agent")
	map("R", function()
		M.restart_agent(list_agent_under_cursor())
	end, "Restart agent")
	map("D", function()
		M.diffview()
	end, "Diffview of agent changes")
	map("<Tab>", function()
		vim.api.nvim_set_current_win(S.wins.changes)
	end, "Go to changes")
	map("q", M.close, "Close hub")

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = buf,
		callback = function()
			local name = list_agent_under_cursor()
			if name and name ~= S.selected then
				select_agent(name, false)
			end
		end,
	})
end

local function map_changes(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	map("<CR>", function()
		preview_change(change_under_cursor())
	end, "Preview diff")
	map("o", function()
		local agent, entry = selected_agent(), change_under_cursor()
		if agent and entry then
			vim.cmd("tabedit " .. vim.fn.fnameescape(agent.cwd .. "/" .. entry.path))
		end
	end, "Open file")
	map("D", function()
		local entry = change_under_cursor()
		M.diffview(entry and entry.path)
	end, "Diffview")
	map("r", refresh_changes, "Refresh")

	-- Keep the cursor on a file line, so ⏎ / o / D always have a file to act
	-- on: entering the panel or moving onto the header or footer snaps to the
	-- nearest file.
	vim.api.nvim_create_autocmd({ "WinEnter", "CursorMoved" }, {
		buffer = buf,
		callback = function()
			if change_under_cursor() then
				return
			end
			local current = vim.api.nvim_win_get_cursor(0)[1]
			local best
			for lnum in pairs(S.change_map) do
				if not best or math.abs(lnum - current) < math.abs(best - current) then
					best = lnum
				end
			end
			if best then
				vim.api.nvim_win_set_cursor(0, { best, 0 })
			end
		end,
	})
	map("<C-Space>", M.jump, "Jump to tab")
	map("O", M.office, "Toggle office view")
	map("b", M.browser, "Open the web result in terminal-browser")
	map("g", M.lazygit, "Lazygit in this agent's repo")
	map("<Tab>", function()
		vim.api.nvim_set_current_win(S.wins.list)
	end, "Go to agents")
	map("q", M.close, "Close hub")
end

local function set_highlights()
	local links = {
		AgentsPanel = "NormalFloat",
		AgentsTitle = "Title",
		AgentsProject = "Directory",
		AgentsDim = "Comment",
		AgentsSel = "CursorLine",
		AgentsBar = "Function",
		AgentsTool = "Normal",
		AgentsToolSel = "Title",
		AgentsFile = "Normal",
		AgentsKey = "Special",
		AgentsJump = "IncSearch",
		AgentsWall = "FloatBorder",
		AgentsFurniture = "Comment",
		AgentsDesk = "Special",
		AgentsPlant = "String",
		AgentsPerson = "Normal",
		AgentsBubble = "Normal",
		AgentsBubbleBorder = "Comment",
		AgentsP1 = "Function",
		AgentsP2 = "String",
		AgentsP3 = "Constant",
		AgentsP4 = "Type",
		AgentsP5 = "Keyword",
		AgentsP6 = "DiagnosticInfo",
		AgentsRunning = "DiagnosticWarn",
		AgentsWaiting = "DiagnosticError",
		AgentsDone = "DiagnosticOk",
		AgentsIdle = "Comment",
		AgentsExited = "DiagnosticError",
		AgentsAdd = "Added",
		AgentsDel = "Removed",
		AgentsChange = "Changed",
	}
	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = target, default = true })
	end
end

-- Switches the center pane between the selected agent's terminal and the office.
function M.office()
	if not hub_open() then
		S.view = "office"
		M.open()
		return
	end
	vim.api.nvim_set_current_tabpage(S.tab)
	if S.view == "office" then
		S.view = "term"
		show_agent(S.selected, false)
	else
		S.view = "office"
		show_agent(S.selected, false)
	end
end

function M._map_office(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	local function under_cursor()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		return office.hit(S.office_rects, lnum, vim.fn.virtcol("."))
	end
	map("<CR>", function()
		local name = under_cursor()
		if name then
			select_agent(name, true)
		end
	end, "Sit with agent")
	map("<2-LeftMouse>", function()
		local name = under_cursor()
		if name then
			select_agent(name, true)
		end
	end, "Sit with agent")
	map("<LeftRelease>", function()
		local name = under_cursor()
		if name and name ~= S.selected then
			select_agent(name, false)
		end
	end, "Select agent")
	map("O", M.office, "Back to terminal")
	map("b", M.browser, "Open the web result in terminal-browser")
	map("g", M.lazygit, "Lazygit in this agent's repo")
	map("q", M.office, "Back to terminal")
	map("<C-Space>", M.jump, "Jump to tab")
	map("<Tab>", function()
		vim.api.nvim_set_current_win(S.wins.list)
	end, "Go to agents")
end

-- Closes the browser only when this Neovim opened it, so another Neovim
-- quitting (or a headless run) never closes your browser.
local function close_own_browser()
	if S.browser_opened then
		S.browser_opened = false
		close_browser()
	end
end

function M.close()
	close_own_browser()
	if not (S.tab and vim.api.nvim_tabpage_is_valid(S.tab)) then
		S.tab = nil
		return
	end
	if #vim.api.nvim_list_tabpages() == 1 then
		vim.cmd("tabnew")
	end
	vim.cmd(vim.api.nvim_tabpage_get_number(S.tab) .. "tabclose")
	S.tab = nil
	S.wins = {}
end

function M.open()
	if hub_open() then
		vim.api.nvim_set_current_tabpage(S.tab)
		return
	end
	if S.tab and vim.api.nvim_tabpage_is_valid(S.tab) then
		M.close()
	end

	vim.cmd("tabnew")
	S.tab = vim.api.nvim_get_current_tabpage()
	local scratch = vim.api.nvim_get_current_buf()
	S.wins.term = vim.api.nvim_get_current_win()

	vim.cmd("topleft vsplit")
	S.wins.list = vim.api.nvim_get_current_win()
	local list_buf = panel_buf("list", "agentlist")
	vim.api.nvim_win_set_buf(S.wins.list, list_buf)
	set_panel_win_options(S.wins.list, config.sidebar_width)

	vim.api.nvim_set_current_win(S.wins.term)
	vim.cmd("botright vsplit")
	S.wins.changes = vim.api.nvim_get_current_win()
	local changes_buf = panel_buf("changes", "agentchanges")
	vim.api.nvim_win_set_buf(S.wins.changes, changes_buf)
	set_panel_win_options(S.wins.changes, config.changes_width)

	if not vim.b[list_buf].agents_mapped then
		map_list(list_buf)
		map_changes(changes_buf)
		vim.b[list_buf].agents_mapped = true
	end

	show_agent(S.selected, false)
	if vim.api.nvim_buf_is_valid(scratch) and scratch ~= vim.api.nvim_win_get_buf(S.wins.term) then
		pcall(vim.api.nvim_buf_delete, scratch, { force = true })
	end
	vim.api.nvim_set_current_win(S.wins.list)

	render_list()
	render_changes()
	start_timer()
	poll(refresh_changes)
end

function M.is_open()
	return hub_open() and true or false
end

function M.toggle()
	if hub_open() and vim.api.nvim_get_current_tabpage() == S.tab then
		if not pcall(vim.cmd, "tabnext #") then
			vim.cmd("tabprevious")
		end
		return
	end
	M.open()
end

-- Compact counts for a statusline: running, needing input, done.
function M.statusline()
	local counts = { running = 0, waiting = 0, done = 0 }
	for _, agent in ipairs(S.agents) do
		local status = status_of(agent.name)
		if counts[status] then
			counts[status] = counts[status] + 1
		end
	end
	local parts = {}
	if counts.running > 0 then
		table.insert(parts, SPINNER[(S.tick % #SPINNER) + 1] .. " " .. counts.running)
	end
	if counts.waiting > 0 then
		table.insert(parts, STATUS.waiting.icon .. " " .. counts.waiting)
	end
	if counts.done > 0 then
		table.insert(parts, STATUS.done.icon .. " " .. counts.done)
	end
	return table.concat(parts, " ")
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	set_highlights()

	local group = vim.api.nvim_create_augroup("Agents", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			set_highlights()
			office.reset_colors()
		end,
	})
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			if hub_open() then
				vim.api.nvim_win_set_width(S.wins.list, config.sidebar_width)
				vim.api.nvim_win_set_width(S.wins.changes, config.changes_width)
			end
		end,
	})
	-- The browser pane belongs to this Neovim; do not leave it behind.
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			close_own_browser()
		end,
	})
	vim.api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			if S.tab and not vim.api.nvim_tabpage_is_valid(S.tab) then
				S.tab = nil
				S.wins = {}
			end
		end,
	})

	vim.api.nvim_create_user_command("Agents", M.toggle, { desc = "Toggle the agent hub" })
	vim.api.nvim_create_user_command("AgentsNew", M.new_agent, { desc = "Start a new desk" })
	vim.api.nvim_create_user_command("AgentsTab", M.new_tab, { desc = "New tab in the selected desk" })
	vim.api.nvim_create_user_command("AgentsJump", M.jump, { desc = "Jump to a tab" })
	vim.api.nvim_create_user_command("AgentsOffice", M.office, { desc = "Toggle the office view" })
	vim.api.nvim_create_user_command("AgentsInstallHooks", function()
		require("agents.hooks").install()
	end, { desc = "Install the Claude Code hooks that report status to the hub" })
	vim.api.nvim_create_user_command("AgentsUninstallHooks", function()
		require("agents.hooks").uninstall()
	end, { desc = "Remove the hub's Claude Code hooks" })
	vim.api.nvim_create_user_command("AgentsBrowser", M.browser, { desc = "Open the web result in terminal-browser" })
	vim.api.nvim_create_user_command("AgentsSend", M.send, { range = true, desc = "Send file reference to agent" })

	vim.keymap.set("n", "<leader>mm", M.toggle, { desc = "Agents: toggle hub" })
	vim.keymap.set("n", "<leader>mn", M.new_agent, { desc = "Agents: new desk" })
	vim.keymap.set("n", "<leader>mt", M.new_tab, { desc = "Agents: new tab in desk" })
	vim.keymap.set("n", "<leader>mj", M.jump, { desc = "Agents: jump to tab" })
	vim.keymap.set("n", "<leader>mo", M.office, { desc = "Agents: office view" })
	vim.keymap.set("n", "<leader>mg", M.lazygit, { desc = "Agents: lazygit in the selected agent's repo" })
	vim.keymap.set("n", "<leader>mb", M.browser, { desc = "Agents: open web result in terminal-browser" })
	vim.keymap.set("n", "<leader>md", function()
		M.diffview()
	end, { desc = "Agents: diffview of selected agent" })
	vim.keymap.set("n", "<leader>ms", "<Cmd>AgentsSend<CR>", { desc = "Agents: send file" })
	vim.keymap.set("x", "<leader>ms", ":AgentsSend<CR>", { desc = "Agents: send selection range" })

	-- Pick up agents left running by an earlier Neovim, so notifications work.
	vim.defer_fn(function()
		poll(function()
			if #S.agents > 0 then
				start_timer()
			end
		end)
	end, 1500)
end

return M
