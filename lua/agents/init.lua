-- Agent hub: a tab with an agent sidebar, the selected agent's terminal and
-- the code it changed. Agents run in tmux (see agents.tmux) so they outlive
-- Neovim; Claude Code reports its state through hooks in ~/.claude/settings.json.
local tmux = require("agents.tmux")
local git = require("agents.git")
local office = require("agents.office")
local flow = require("agents.flow")
local wowo = require("agents.wowo")
local review = require("agents.review")
local handoff = require("agents.handoff")
local queue = require("agents.queue")
local usage = require("agents.usage")

local M = {}

local config = {
	roots = { "~/_dev" },
	scan_depth = 3,
	tools = { "claude", "omp", "wowo", "opencode", "codex", "pi", "hermes" },
	-- wowo, the hub's bring-your-own-key agent: see lua/agents/wowo.lua.
	wowo = {},
	sidebar_width = 34,
	changes_width = 46,
	-- Below this many columns (a phone, a small window) the hub stacks the
	-- sidebar over the changes panel in one narrow column, leaving the rest
	-- to the agent.
	compact_below = 120,
	-- Below this many columns (a phone held upright) the panels stack over
	-- each other at full width: tabs on top, the agent below, the changes
	-- panel folded to its header line until you enter it.
	phone_below = 80,
	-- Continue a limited agent in its partner CLI; stops when both are limited.
	handoff = { auto = true, partners = { claude = "omp", omp = "claude" } },
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
	limited = { icon = "\u{f071}", label = "limit reached", hl = "AgentsWaiting" },
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
	limited = {}, -- name -> usage-limit message seen on its screen
	limit_checked = {}, -- name -> last screen check (os.time)
	stale_checked = {}, -- name -> last check of a quiet "running" tab
	tails = {}, -- name -> last screen line, for tabs without hooks
	office_rects = {},
	office_desk = nil, -- desk (project) picked in the office, instead of one agent
	sent = {}, -- name -> { text, at = vim.uv.now() }: prompts just sent, for the office
	sending_until = 0, -- the office animates every tick until then
}

-- Runs a command and waits; a missing program reads as exit code 127
-- instead of an error (vim.system throws when it cannot start).
local function run_wait(cmd, timeout)
	local ok, job = pcall(vim.system, cmd, { text = true })
	if not ok then
		return { code = 127, stdout = "", stderr = cmd[1] .. " is not installed" }
	end
	return job:wait(timeout)
end

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
	local message, level
	if after == "waiting" then
		message, level = "needs input", vim.log.levels.WARN
	elseif before == "running" and after == "done" then
		message, level = "is done", vim.log.levels.INFO
	elseif after == "exited" then
		message, level = "exited", vim.log.levels.WARN
	end
	if message then
		vim.notify(agent_label(agent) .. " " .. message, level, { title = "Agents" })
		flow.system_notify(agent.project, display_name(agent) .. " " .. message)
	end
end

-- Sidebar ---------------------------------------------------------------------

local phone_heights -- set with the hub layout below

local function render_list()
	if not hub_open() then
		return
	end
	local total = vim.api.nvim_win_get_width(S.wins.list)
	local canvas = new_canvas()
	S.list_map = {}
	S.desk_map = {} -- sidebar line -> desk (project) of a desk header

	-- On a phone the tab bar already names the panel.
	if S.layout ~= "phone" then
		push(canvas, row({ { " AGENTS", "AgentsTitle" } }, { { tostring(#S.agents) .. " ", "AgentsDim" } }, total))
		push(canvas, { { "" } })
	end

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
			local header = push(canvas, row({ { "  ▾ ", "AgentsDim" }, { trunc(project, total - 14), "AgentsProject" } }, right, total))
			S.desk_map[header] = project
		end

		local status = status_of(agent.name)
		local spec = STATUS[status]
		local is_selected = agent.name == S.selected
		local line_hl = is_selected and "AgentsSel" or nil
		local changes = S.changes[agent.cwd]
		local stat = changes and diffstat(changes.add, changes.del) or {}
		local badge, badge_hl = queue.badge(agent.name)
		if badge then
			table.insert(stat, 1, { badge .. " ", badge_hl })
		end
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
		local ctx = usage.context(agent)
		local ctx_segs = ctx and { { usage.format(ctx), usage.hl(ctx) }, { " " } } or {}
		local room = total - seg_width(detail) - seg_width(ctx_segs) - 4
		if doing then
			table.insert(detail, { " · " .. trunc(doing, room - 1), "AgentsDim" })
		elseif branch then
			table.insert(detail, { "  " .. BRANCH_ICON .. " " .. trunc(branch, room - 1), "AgentsDim" })
		end
		local second = push(canvas, row(detail, ctx_segs, total), line_hl)

		S.list_map[first] = agent.name
		S.list_map[second] = agent.name
	end

	push(canvas, { { "" } })
	-- A phone has no room for the key hints; ? lists them.
	S.hint_map = {}
	if S.layout == "phone" then
		-- A phone: the keys as buttons to tap, packed into rows.
		local buttons = {
			{ "<CR>", "⏎", "open" }, { "p", "p", "prompt" }, { "a", "a", "approve" }, { "e", "e", "esc" },
			{ "t", "t", "tab" }, { "T", "T", "terminal" }, { "n", "n", "desk" }, { "R", "R", "restart" },
			{ "O", "O", "office", true }, { "G", "G", "grid" }, { "A", "A", "monitor" }, { "f", "f", "find" },
			{ "x", "x", "remove" }, { "?", "?", "all keys" },
		}
		local segs, width, hits = { { " " } }, 1, {}
		local function flush()
			-- A gap between rows: bigger targets for a finger.
			push(canvas, { { "" } })
			local lnum = push(canvas, segs)
			S.hint_map[lnum] = hits
			segs, width, hits = { { " " } }, 1, {}
		end
		for _, b in ipairs(buttons) do
			local label = " " .. b[2] .. " " .. b[3] .. " "
			local w = vim.fn.strdisplaywidth(label)
			if width + w + 1 > total and #hits > 0 then
				flush()
			end
			local start = 0
			for _, seg in ipairs(segs) do
				start = start + #seg[1]
			end
			table.insert(hits, { start + 1, start + #label, b[1], b[4] })
			vim.list_extend(segs, { { label, "AgentsChip" }, { " " } })
			width = width + w + 1
		end
		flush()
	end
	local keys = S.layout == "phone" and {} or {
		{ { "n", "desk" }, { "t", "tab" }, { "T", "terminal" } },
		{ { "p", "prompt" }, { "a", "approve" }, { "F", "fan-out" } },
		{ { "f", "find" }, { "⏎", "focus" }, { "O", "office" } },
		{ { "G", "grid" }, { "E", "files" }, { "A", "monitor" } },
		{ { "x", "remove" }, { "X", "remove desk" }, { "R", "restart" } },
		{ { "?", "all keys" } },
	}
	for _, line in ipairs(keys) do
		local segs = { { " " } }
		for _, key in ipairs(line) do
			vim.list_extend(segs, { { key[1], "AgentsKey" }, { " " .. key[2] .. "   ", "AgentsDim" } })
		end
		push(canvas, segs)
	end

	paint(S.bufs.list, canvas)
	if S.layout == "phone" then
		phone_heights()
	end

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
	local total = vim.api.nvim_win_get_width(S.wins.changes)
	local canvas = new_canvas()
	S.change_map = {}
	local agent = selected_agent()
	local info = agent and S.changes[agent.cwd]

	local pending = agent and review.count(agent.name) or 0
	if S.layout ~= "phone" then
		push(canvas, row({ { " CHANGES", "AgentsTitle" } }, {
			{ pending > 0 and ("● " .. pending .. " to send  ") or "", "DiagnosticInfo" },
			{ info and (#info.files .. (#info.files == 1 and " file " or " files ")) or "", "AgentsDim" },
		}, total))
	end

	if not agent then
		push(canvas, { { "" } })
		push(canvas, { { "  No agent selected.", "AgentsDim" } })
	elseif not info then
		push(canvas, { { "" } })
		push(canvas, { { "  " .. trunc(vim.fn.fnamemodify(agent.cwd, ":~"), total - 3), "AgentsDim" } })
		push(canvas, { { "  Loading, or not a git repository.", "AgentsDim" } })
	else
		local function file_line(entry, indent)
			local stat = entry.binary and { { "bin", "AgentsDim" } } or diffstat(entry.add, entry.del)
			table.insert(stat, { " " })
			local name = vim.fs.basename(entry.path)
			local dir = vim.fs.dirname(entry.path)
			local left = {
				{ indent },
				{ KIND_LABEL[entry.kind] or entry.kind, KIND_HL[entry.kind] },
				{ " " },
				{ trunc(name, total - seg_width(stat) - 5 - #indent), entry.kind == "D" and "AgentsDim" or "AgentsFile" },
			}
			local room = total - seg_width(left) - seg_width(stat) - 2
			if dir ~= "." and room > 4 then
				table.insert(left, { " " .. trunc_left(dir, room), "AgentsDim" })
			end
			local lnum = push(canvas, row(left, stat, total))
			S.change_map[lnum] = entry
		end
		if info.repos then
			-- A folder holding several repos: one group per repo.
			push(
				canvas,
				row(
					{ { " ⊞ ", "AgentsDim" }, { #info.repos .. " repos", "AgentsProject" } },
					vim.list_extend(diffstat(info.add, info.del), { { " " } }),
					total
				)
			)
			push(canvas, { { " " .. trunc_left(vim.fn.fnamemodify(agent.cwd, ":~"), total - 2), "AgentsDim" } })
			for _, repo in ipairs(info.repos) do
				push(canvas, { { "" } })
				local stat = vim.list_extend(diffstat(repo.info.add, repo.info.del), { { " " } })
				local branch = " " .. BRANCH_ICON .. " " .. (repo.info.branch or "detached")
				local left = { { " ▾ " .. repo.name, "AgentsProject" } }
				local room = total - seg_width(left) - seg_width(stat) - 2
				if room > 4 then
					table.insert(left, { trunc(branch, room), "AgentsDim" })
				end
				push(canvas, row(left, stat, total))
				if #repo.info.files == 0 then
					push(canvas, { { "   clean", "AgentsDim" } })
				end
				for _, entry in ipairs(repo.info.files) do
					file_line(entry, "   ")
				end
			end
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
				file_line(entry, " ")
			end
		end
	end

	push(canvas, { { "" } })
	push(canvas, {
		{ " ⏎", "AgentsKey" },
		{ " preview   ", "AgentsDim" },
		{ "o", "AgentsKey" },
		{ " open   ", "AgentsDim" },
		{ "D", "AgentsKey" },
		{ " diffview", "AgentsDim" },
	})
	push(canvas, {
		{ " g", "AgentsKey" },
		{ " lazygit   ", "AgentsDim" },
		{ "S", "AgentsKey" },
		{ " send review   ", "AgentsDim" },
		{ "?", "AgentsKey" },
		{ " keys", "AgentsDim" },
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
		context_of = usage.context,
		selected = S.selected,
		jump_labels = S.jump_labels,
		selected_desk = S.office_desk,
		sent = S.sent,
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
	if S.layout == "phone" then
		-- The phone tab bar stands in for the winbar.
		phone_heights()
		return
	end
	if S.view == "office" then
		local target = S.office_desk and ("desk " .. S.office_desk)
			or (selected_agent() and display_name(selected_agent()))
		vim.wo[S.wins.term].winbar = "%#AgentsTitle#  Agent Office "
			.. (target and ("%#AgentsToolSel# ✉ " .. target:gsub("%%", "%%%%") .. " ") or "")
			.. "%#AgentsDim#  p prompt  P desk  hjkl move  ⏎ sit  x remove  O terminal  ? keys"
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
	local status_text = status_of(agent.name) == "exited" and "exited · ⏎ or R resumes" or spec.label
	vim.list_extend(parts, { "%=%#", spec.hl, "#", status_text, " " })
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
		-- An agent that exited cannot take input; Enter brings it back, resuming
		-- its conversation, so typing a prompt just works again.
		vim.keymap.set("t", "<CR>", function()
			if status_of(name) == "exited" then
				vim.schedule(function()
					M.restart_agent(name)
				end)
				return ""
			end
			return "<CR>"
		end, { buffer = buf, expr = true, desc = "Enter, or resume an exited agent" })
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
	S.office_desk = nil
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
		if status == "running" then
			-- Working again: whatever limit it hit is over.
			if S.limited[agent.name] or status ~= (S.meta[agent.name] or {}).status then
				S.limited[agent.name] = nil
				handoff.clear(agent)
			end
		elseif S.limited[agent.name] and status ~= "exited" then
			status = "limited"
		end
		local meta = S.meta[agent.name]
		if not meta then
			S.meta[agent.name] = { status = status, since = os.time() }
		elseif meta.status ~= status then
			local before = meta.status
			notify_transition(agent, before, status)
			meta.status, meta.since = status, os.time()
			if status == "limited" then
				handoff.on_limited(agent, S.limited[agent.name] or agent.activity_text or "usage limit reached")
			end
			vim.schedule(function()
				queue.on_status(agent, before, status)
			end)
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

-- Saved tabs ------------------------------------------------------------------
-- Tabs live in tmux, so they survive Neovim but not a reboot or shutdown,
-- which kill the tmux server. The hub keeps a snapshot of its tabs; when it
-- finds the server empty it starts them again, each agent resuming its
-- conversation (shells and commands just start again in their folder).

local SNAPSHOT = vim.fn.stdpath("state") .. "/agents/tabs.json"
local SAVED = { "name", "project", "tool", "index", "cwd", "branch", "label", "command", "claude_session", "session_id" }

local function save_snapshot(list)
	local rows = {}
	for _, agent in ipairs(list) do
		local row = {}
		for _, key in ipairs(SAVED) do
			row[key] = agent[key]
		end
		table.insert(rows, row)
	end
	local text = #rows == 0 and "[]" or vim.json.encode(rows)
	if text == S.snapshot then
		return
	end
	S.snapshot = text
	vim.fn.mkdir(vim.fs.dirname(SNAPSHOT), "p")
	vim.fn.writefile({ text }, SNAPSHOT)
end

-- Starts the saved tabs again when the tmux server came up empty. Returns
-- how many were started.
local function restore_snapshot(list)
	S.restore_checked = true
	if #list > 0 or vim.fn.filereadable(SNAPSHOT) == 0 then
		return 0
	end
	local ok, rows = pcall(vim.json.decode, table.concat(vim.fn.readfile(SNAPSHOT), "\n"))
	if not ok or type(rows) ~= "table" then
		return 0
	end
	local started, skipped = 0, {}
	for _, row in ipairs(rows) do
		if type(row) == "table" and row.name and row.tool and row.cwd and vim.fn.isdirectory(row.cwd) == 1 then
			local done = tmux.new_session({
				name = row.name,
				cwd = row.cwd,
				command = flow.restart_command(row),
				options = {
					project = row.project,
					tool = row.tool,
					index = row.index or 1,
					cwd = row.cwd,
					branch = row.branch or "",
					command = row.command or row.tool,
					label = row.label or "",
					claude_session = row.claude_session or "",
					session_id = row.session_id or "",
				},
			})
			if done then
				started = started + 1
			end
		elseif type(row) == "table" then
			table.insert(skipped, row.name or "?")
		end
	end
	if started > 0 then
		vim.notify(
			("Restored %d %s from before the restart"):format(started, started == 1 and "tab" or "tabs")
				.. (#skipped > 0 and ("\nSkipped (folder gone): " .. table.concat(skipped, ", ")) or ""),
			vim.log.levels.INFO,
			{ title = "Agents" }
		)
	end
	return started
end

local function poll(cb)
	tmux.list(function(list)
		if not S.restore_checked and restore_snapshot(list) > 0 then
			poll(cb)
			return
		end
		save_snapshot(list)
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
			queue.render()
			-- No hook fires when you interrupt an agent (Esc), so "running"
			-- from its hooks can go stale. When a "running" tab has been quiet
			-- for a few seconds, read its screen: an "Interrupted" line, or
			-- (Claude) no "esc to interrupt" hint, means it is no longer working.
			for _, agent in ipairs(S.agents) do
				local quiet = os.time() - agent.activity >= 4
				local due = os.time() - (S.stale_checked[agent.name] or 0) >= 4
				if agent.hook == "running" and quiet and due then
					S.stale_checked[agent.name] = os.time()
					tmux.run({ "capture-pane", "-p", "-J", "-t", "=" .. agent.name .. ":" }, function(result)
						if result.code ~= 0 then
							return
						end
						local lines = {}
						for line in vim.gsplit(result.stdout or "", "\n") do
							if vim.trim(line) ~= "" then
								table.insert(lines, line)
							end
						end
						local tail = table.concat(vim.list_slice(lines, math.max(1, #lines - 12), #lines), "\n"):lower()
						local interrupted = tail:find("interrupted", 1, true) ~= nil
						local claude_idle = agent.tool == "claude" and not tail:find("esc to interrupt", 1, true)
						if interrupted or claude_idle then
							tmux.set_option(agent.name, "status", "idle")
							tmux.set_option(agent.name, "activity", interrupted and "interrupted" or "")
						end
					end)
				end
			end
			-- An agent that stopped may be stopped by a usage limit: look at
			-- the bottom of its screen (every few seconds, idle agents only).
			for _, agent in ipairs(S.agents) do
				local status = status_of(agent.name)
				local due = os.time() - (S.limit_checked[agent.name] or 0) >= 6
				if due and (status == "done" or status == "idle" or status == "waiting") and not S.limited[agent.name] then
					S.limit_checked[agent.name] = os.time()
					handoff.check_screen(agent, function(message)
						if message and not S.limited[agent.name] and status_of(agent.name) ~= "running" then
							S.limited[agent.name] = message
							tmux.set_option(agent.name, "activity", message)
						end
					end)
				end
			end
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
		queue.tick()
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
	elseif hub_open() and vim.uv.now() < S.sending_until then
		render_office()
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
	local ok, job = pcall(vim.system, { "git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true })
	if not ok then
		return nil
	end
	local result = job:wait()
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
			command = spec.command,
			label = spec.label or "",
		},
	})
	if not ok then
		vim.notify("Could not start " .. spec.tool .. ": " .. err, vim.log.levels.ERROR, { title = "Agents" })
		return
	end

	local focus = spec.focus ~= false
	if focus then
		S.selected = name
	end
	M.open()
	start_timer()
	poll(function()
		refresh_changes()
		if focus then
			select_agent(name, true)
		end
	end)
	return name
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

local SHELL_TAB = "terminal (" .. vim.fs.basename(vim.o.shell) .. ")"
local CUSTOM_TAB = "custom command…"

-- Asks what a tab runs: an agent CLI, a plain shell, or any command
-- (a dev server, tests in watch mode). cb(tool, command).
local function choose_command(with_extras, cb)
	local items = vim.tbl_filter(function(tool)
		if tool == "wowo" then
			return wowo.available()
		end
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
		elseif choice == "wowo" then
			wowo.choose(pick, function(command)
				cb("wowo", command)
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
					local result = run_wait({ "git", "init", "-q", path })
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

-- New plain terminal tab in the selected desk's folder (or worktree), to run
-- the project: a dev server, tests, git.
function M.new_terminal()
	local agent = selected_agent()
	if not agent then
		M.new_agent()
		return
	end
	local shell = vim.o.shell
	create_agent({ project = agent.project, cwd = agent.cwd, tool = vim.fs.basename(shell), command = shell })
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

-- Removes tabs: closes their terminals after one confirmation. The
-- conversations stay on disk, so a CLI can resume them later.
function M.remove_agents(names, what)
	names = vim.tbl_filter(function(name)
		return S.by_name[name] ~= nil
	end, names)
	if #names == 0 then
		return
	end
	local busy = vim.tbl_filter(function(name)
		local st = status_of(name)
		return st == "running" or st == "waiting"
	end, names)
	local question = ("Remove %s?"):format(what)
	if #busy > 0 then
		question = question .. ("\n%d still working; it stops now."):format(#busy)
	end
	if vim.fn.confirm(question, "&Remove\n&Cancel", 2) ~= 1 then
		return
	end
	local next_selected
	if vim.tbl_contains(names, S.selected) then
		for _, agent in ipairs(S.agents) do
			if not vim.tbl_contains(names, agent.name) then
				next_selected = agent.name
				break
			end
		end
	end
	for _, name in ipairs(names) do
		tmux.kill(name)
		S.meta[name] = nil
		S.sent[name] = nil
	end
	if vim.tbl_contains(names, S.selected) then
		S.selected = next_selected
		S.office_desk = nil
	end
	poll(function()
		refresh_changes()
		if hub_open() and S.view ~= "office" then
			show_agent(S.selected, false)
		end
	end)
end

function M.kill_agent(name)
	name = name or S.selected
	local agent = name and S.by_name[name]
	if agent then
		M.remove_agents({ name }, agent_label(agent))
	end
end

-- Removes every tab of a desk (project).
function M.remove_desk(project)
	local names = {}
	for _, agent in ipairs(S.agents) do
		if agent.project == project then
			table.insert(names, agent.name)
		end
	end
	if #names > 0 then
		M.remove_agents(names, ("desk %s (%d %s)"):format(project, #names, #names == 1 and "tab" or "tabs"))
	end
end

function M.restart_agent(name)
	name = name or S.selected
	if not (name and S.by_name[name]) then
		return
	end
	tmux.respawn(name, flow.restart_command(S.by_name[name]))
	poll()
end

local function load_diffview()
	local ok, lazy = pcall(require, "lazy")
	if ok then
		lazy.load({ plugins = { "diffview.nvim" } })
	end
end

-- The repository to run git tools in: the entry's own repo when the folder
-- holds several, else the first of them, else the agent's folder.
local function repo_of(agent, entry)
	if entry and entry.repo then
		return entry.repo
	end
	local info = S.changes[agent.cwd]
	return info and info.repos and info.repos[1].cwd or agent.cwd
end

-- The entry's path from the agent's folder (repo folder first when it has several).
local function path_of(entry)
	return entry.prefix and (entry.prefix .. "/" .. entry.path) or entry.path
end

function M.diffview(path, repo)
	local agent = selected_agent()
	if not agent then
		return
	end
	load_diffview()
	local cmd = "DiffviewOpen -C" .. vim.fn.fnameescape(repo or repo_of(agent))
	if path then
		cmd = cmd .. " -- " .. vim.fn.fnameescape(path)
	end
	if not pcall(vim.cmd, cmd) then
		vim.notify("Diffview is not available (sindrets/diffview.nvim)", vim.log.levels.WARN, { title = "Agents" })
	end
end

local function preview_change(entry)
	local agent = selected_agent()
	if not (agent and entry) then
		return
	end
	git.diff(repo_of(agent, entry), entry, function(lines)
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
			title = " " .. path_of(entry) .. " ",
			title_pos = "center",
			footer = " c comment   S send comments   o open file   D diffview   q close ",
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
			M.workspace(agent.cwd, path_of(entry))
		end, opts)
		vim.keymap.set("n", "D", function()
			close()
			M.diffview(entry.path, repo_of(agent, entry))
		end, opts)
		review.attach(buf, agent.name, path_of(entry))
		vim.keymap.set("n", "S", function()
			close()
			M.send_review()
		end, opts)
	end)
end

-- Sends the pending review comments to the selected agent as one prompt.
function M.send_review()
	local agent = selected_agent()
	if not agent then
		return
	end
	local text = review.take(agent.name)
	if not text then
		vim.notify("No review comments yet: press c on a line in the diff preview", vim.log.levels.INFO, { title = "Agents" })
		return
	end
	flow.submit(agent.name, text)
	render_changes()
	vim.notify("Sent review to " .. agent_label(agent), vim.log.levels.INFO, { title = "Agents" })
end

local HELP = {
	{ "Sidebar", "" },
	{ "j / k", "select tab" },
	{ "⏎ / 1-9", "focus tab" },
	{ "n", "new desk (project, agent, worktree)" },
	{ "t", "new tab in this desk (agent, terminal or command)" },
	{ "T", "new terminal tab in this desk's folder" },
	{ "p", "type a prompt to the agent" },
	{ "a", "approve its permission prompt" },
	{ "e", "Esc: decline / interrupt" },
	{ "F", "fan out one prompt to N worktrees" },
	{ "f", "find a tab" },
	{ "r / x / R", "rename / remove / restart (resumes the conversation)" },
	{ "X", "remove the whole desk (x on a desk header too)" },
	{ "P", "push branch and open a PR" },
	{ "M", "merge worktree branch into main repo" },
	{ "W", "remove worktree" },
	{ "D / g", "Diffview / lazygit" },
	{ "b", "terminal-browser" },
	{ "O", "office view" },
	{ "A", "usage monitor (all agents)" },
	{ "G", "mission control grid" },
	{ "H", "hand off to another CLI (auto on limit)" },
	{ "Q", "autopilot: queue of prompts (s start/stop)" },
	{ "E", "open the folder as a workspace (files, edit)" },
	{ "Ctrl-Space", "jump mode" },
	{ "q", "close hub" },
	{ "", "" },
	{ "Changes", "" },
	{ "⏎", "diff preview (c comment, S send)" },
	{ "o / D", "open file in workspace / Diffview" },
	{ "E", "open the folder as a workspace" },
	{ "S", "send review comments" },
	{ "r", "refresh" },
	{ "", "" },
	{ "Office", "" },
	{ "h j k l", "move between cubicles and desks" },
	{ "p", "prompt the agent or desk under the cursor" },
	{ "P", "prompt the whole desk" },
	{ "Tab (in the box)", "next recipient: desk, free seats, a seat, new agent" },
	{ "⏎", "sit with the agent / prompt the desk" },
	{ "x", "remove the agent or desk under the cursor" },
}

function M.help()
	local lines = {}
	for _, item in ipairs(HELP) do
		if item[2] == "" then
			table.insert(lines, item[1] ~= "" and (" " .. item[1]) or "")
		else
			table.insert(lines, ("   %-12s %s"):format(item[1], item[2]))
		end
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	local w, h = 58, #lines
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		border = "rounded",
		style = "minimal",
		title = " Agent hub keys ",
		title_pos = "center",
	})
	for i, item in ipairs(HELP) do
		if item[2] == "" and item[1] ~= "" then
			vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace("agents_help"), i - 1, 0, { end_col = #lines[i], hl_group = "AgentsTitle" })
		end
	end
	for _, lhs in ipairs({ "q", "<Esc>", "?" }) do
		vim.keymap.set("n", lhs, function()
			vim.api.nvim_win_close(win, true)
		end, { buffer = buf, nowait = true })
	end
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

-- Workspace: a tab rooted at an agent's folder (tab-local cwd), so the file
-- tree, find files and grep all work in that project. One tab per folder.
S.workspaces = {} -- cwd -> tabpage

local function open_tree(cwd)
	local ok, api = pcall(require, "nvim-tree.api")
	if ok then
		pcall(api.tree.open, { path = cwd })
	elseif vim.fn.exists(":Explore") == 2 then
		vim.cmd("Explore " .. vim.fn.fnameescape(cwd))
	end
end

function M.workspace(path, file)
	local agent = selected_agent()
	local cwd = path or (agent and agent.cwd)
	if not cwd or vim.fn.isdirectory(cwd) == 0 then
		vim.notify("No agent folder to open", vim.log.levels.WARN, { title = "Agents" })
		return
	end
	local tab = S.workspaces[cwd]
	if tab and vim.api.nvim_tabpage_is_valid(tab) then
		vim.api.nvim_set_current_tabpage(tab)
	else
		vim.cmd("tabnew")
		tab = vim.api.nvim_get_current_tabpage()
		S.workspaces[cwd] = tab
		vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
		vim.t.agents_workspace = cwd
		vim.notify(
			("Workspace %s\n<leader>n file tree · <leader>ff find · <leader>fg grep · <leader>mm back to agents"):format(vim.fn.fnamemodify(cwd, ":~")),
			vim.log.levels.INFO,
			{ title = "Agents" }
		)
	end
	if file then
		vim.cmd("edit " .. vim.fn.fnameescape(cwd .. "/" .. file))
	elseif vim.api.nvim_buf_get_name(0) == "" then
		open_tree(cwd)
	end
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
			dir = repo_of(agent, vim.api.nvim_get_current_win() == S.wins.changes and change_under_cursor() or nil),
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
	local running = run_wait({ "pgrep", "-f", BROWSER_PROCESS }, 2000).code == 0
	if running then
		run_wait({ "pkill", "-TERM", "-f", BROWSER_PROCESS }, 2000)
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
	-- A tap on a key button (phone layout) presses that key.
	vim.keymap.set("n", "<LeftMouse>", function()
		local pos = vim.fn.getmousepos()
		for _, hit in ipairs(S.hint_map and S.hint_map[pos.line] or {}) do
			if pos.winid == S.wins.list and pos.column >= hit[1] and pos.column <= hit[2] then
				vim.schedule(function()
					vim.api.nvim_set_current_win(S.wins.list)
					vim.api.nvim_feedkeys(vim.keycode(hit[3]), "mx", false)
					-- Keys that change the main view (office) show it.
					if hit[4] and hub_open() then
						vim.api.nvim_set_current_win(S.wins.term)
					end
				end)
				return ""
			end
		end
		return "<LeftMouse>"
	end, { buffer = buf, expr = true, desc = "Click, or press a key button" })
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
	map("T", M.new_terminal, "New terminal tab in desk")
	map("r", function()
		M.rename(list_agent_under_cursor())
	end, "Rename tab")
	map("<C-Space>", M.jump, "Jump to tab")
	map("O", M.office, "Toggle office view")
	map("b", M.browser, "Open the web result in terminal-browser")
	map("g", M.lazygit, "Lazygit in this agent's repo")
	map("p", flow.prompt, "Prompt the agent")
	map("a", flow.approve, "Approve the permission prompt")
	map("e", flow.deny, "Esc: decline or interrupt")
	map("F", flow.fanout, "Fan out a prompt to worktrees")
	map("f", flow.find, "Find a tab")
	map("P", flow.pull_request, "Push and open a PR")
	map("M", flow.merge, "Merge worktree branch")
	map("W", flow.remove_worktree, "Remove worktree")
	map("?", M.help, "All keys")
	map("A", function()
		require("agents.monitor").open()
	end, "Usage monitor")
	map("G", function()
		require("agents.grid").open()
	end, "Mission control grid")
	map("H", handoff.handoff_selected, "Hand off to another agent CLI")
	map("Q", queue.open, "Autopilot prompt queue")
	map("E", function()
		M.workspace()
	end, "Open the folder as a workspace")
	for i = 1, 9 do
		map(tostring(i), function()
			if S.agents[i] then
				select_agent(S.agents[i].name, true)
			end
		end, "Focus tab " .. i)
	end
	map("x", function()
		local lnum = vim.api.nvim_win_get_cursor(S.wins.list)[1]
		if S.desk_map and S.desk_map[lnum] then
			M.remove_desk(S.desk_map[lnum])
		else
			M.kill_agent(list_agent_under_cursor())
		end
	end, "Remove the tab (or the desk on its header)")
	map("X", function()
		local lnum = vim.api.nvim_win_get_cursor(S.wins.list)[1]
		local name = list_agent_under_cursor()
		local project = (S.desk_map and S.desk_map[lnum]) or (name and S.by_name[name] and S.by_name[name].project)
		if project then
			M.remove_desk(project)
		end
	end, "Remove every tab of the desk")
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
			M.workspace(agent.cwd, path_of(entry))
		end
	end, "Open file in the folder's workspace")
	map("E", function()
		M.workspace()
	end, "Open the folder as a workspace")
	map("D", function()
		local agent, entry = selected_agent(), change_under_cursor()
		M.diffview(entry and entry.path, agent and repo_of(agent, entry))
	end, "Diffview")
	map("r", refresh_changes, "Refresh")
	map("S", M.send_review, "Send review comments")
	map("?", M.help, "All keys")

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
		AgentsSegment = "Comment",
	}
	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = target, default = true })
	end
	-- The phone tab bar: the open segment as a solid pill.
	local title = vim.api.nvim_get_hl(0, { name = "Title", link = false })
	local panel = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
	vim.api.nvim_set_hl(0, "AgentsSegmentOn", { fg = panel.bg or 0x1b1416, bg = title.fg or 0xff9f1c, bold = true, default = true })
	vim.api.nvim_set_hl(0, "AgentsSegmentBar", { bg = panel.bg, default = true })
	local key = vim.api.nvim_get_hl(0, { name = "Special", link = false })
	local sel = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
	vim.api.nvim_set_hl(0, "AgentsChip", { fg = key.fg, bg = sel.bg, default = true })
	-- Title bar of a mission-control tile that is waiting for you.
	vim.api.nvim_set_hl(0, "AgentsWaitingBar", { fg = "#1d1f27", bg = "#f56565", bold = true, default = true })
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

-- Remembers a prompt sent to an agent, so the office shows it arriving.
local function note_sent(name, text)
	S.sent[name] = { text = text, at = vim.uv.now() }
	S.sending_until = vim.uv.now() + 6100
	render_office()
end

-- Recipients for a prompt written in the office: the agent, its whole desk,
-- the desk's free seats, each seat, or a new agent at the desk. `first` is
-- "agent" or "desk", the recipient picked when the box opens.
local function office_targets(project, agent, first)
	local members = vim.tbl_filter(function(a)
		return a.project == project
	end, S.agents)
	local live = vim.tbl_filter(function(a)
		return status_of(a.name) ~= "exited"
	end, members)
	local free = vim.tbl_filter(function(a)
		local st = status_of(a.name)
		return st ~= "running" and st ~= "waiting"
	end, live)
	local home = agent or live[1] or members[1]
	local function send_all(list)
		return function(text)
			for _, a in ipairs(list) do
				flow.submit(a.name, text)
			end
		end
	end

	local targets, index = {}, 1
	local function add(t)
		table.insert(targets, t)
		return #targets
	end
	if agent then
		local i = add({
			label = display_name(agent) .. " · " .. project,
			agent = agent,
			run = function(text)
				flow.submit(agent.name, text)
			end,
		})
		index = first == "agent" and i or index
	end
	if #live > 1 or not agent then
		local i = add({
			label = ("whole desk %s · %d %s"):format(project, #live, #live == 1 and "seat" or "seats"),
			agent = home,
			run = send_all(live),
		})
		index = first == "desk" and i or index
		if #free > 0 and #free < #live then
			add({ label = ("free seats at %s · %d"):format(project, #free), agent = free[1], run = send_all(free) })
		end
	end
	for _, a in ipairs(live) do
		if a ~= agent then
			add({
				label = display_name(a) .. " · " .. project,
				agent = a,
				run = function(text)
					flow.submit(a.name, text)
				end,
			})
		end
	end
	if home then
		add({
			label = "new agent at " .. project,
			agent = home,
			run = function(text)
				choose_command(false, function(tool, command)
					local cmd = flow.first_prompt_command(tool, command, text)
					local name = create_agent({ project = project, cwd = home.cwd, tool = tool, command = cmd, focus = false })
					if not name then
						return
					end
					if cmd == command then
						-- A CLI without a first-prompt flag: type it in once it is up.
						vim.defer_fn(function()
							flow.submit(name, text)
						end, 5000)
					else
						note_sent(name, text)
					end
				end)
			end,
		})
	end
	return targets, index
end

-- Opens the prompt box for an office target: { name = agent } or { desk = project }.
local function office_prompt(target, first)
	local agent = target.name and S.by_name[target.name]
	local project = target.desk or (agent and agent.project)
	if not project then
		return
	end
	local targets, index = office_targets(project, agent, first or (agent and "agent" or "desk"))
	if #targets == 0 then
		return
	end
	require("agents.prompt_box").open(nil, "", nil, { targets = targets, index = index })
end

function M._map_office(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	local function under_cursor()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		return office.hit(S.office_rects, lnum, vim.fn.virtcol("."))
	end
	local function rect_of_selection()
		for _, r in ipairs(S.office_rects) do
			if (S.office_desk and r.desk == S.office_desk) or (not S.office_desk and r.name and r.name == S.selected) then
				return r
			end
		end
	end
	-- The office target: what the cursor is on, else what is selected.
	local function target()
		return under_cursor() or rect_of_selection()
	end
	-- Makes `r` the selection: an agent, or a whole desk.
	local function pick_rect(r)
		if not r then
			return
		end
		if r.desk then
			if S.office_desk ~= r.desk then
				S.office_desk = r.desk
				render_list()
				render_office()
				update_winbar()
			end
		elseif r.name ~= S.selected or S.office_desk then
			select_agent(r.name, false)
		end
	end
	local function move(dir)
		return function()
			local from = target()
			local to = from and office.neighbour(S.office_rects, from, dir) or S.office_rects[1]
			if not to then
				return
			end
			-- Land on the nameplate (or the desk label), in the middle.
			local lnum = to.desk and to.top or math.max(to.top, to.bottom - 1)
			local vcol = math.floor((to.left + to.right) / 2)
			local col = vim.fn.virtcol2col(0, lnum, vcol)
			pcall(vim.api.nvim_win_set_cursor, 0, { lnum, math.max(0, col - 1) })
			pick_rect(to)
		end
	end

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = buf,
		callback = function()
			pick_rect(under_cursor())
		end,
	})
	map("<CR>", function()
		local r = under_cursor()
		if r and r.desk then
			office_prompt(r, "desk")
		elseif r then
			select_agent(r.name, true)
		end
	end, "Sit with agent / prompt the desk")
	map("<2-LeftMouse>", function()
		local r = under_cursor()
		if r and r.name then
			select_agent(r.name, true)
		end
	end, "Sit with agent")
	map("<LeftRelease>", function()
		pick_rect(under_cursor())
	end, "Select agent or desk")
	for _, dir in ipairs({ "h", "j", "k", "l" }) do
		map(dir, move(dir), "Move to the next cubicle or desk")
	end
	map("p", function()
		local r = target()
		if r then
			office_prompt(r)
		end
	end, "Prompt the agent or desk under the cursor")
	map("P", function()
		local r = target()
		if r then
			office_prompt(r, "desk")
		end
	end, "Prompt the whole desk")
	map("a", flow.approve, "Approve the selected agent")
	map("x", function()
		local r = target()
		if r and r.desk then
			M.remove_desk(r.desk)
		elseif r then
			M.kill_agent(r.name)
		end
	end, "Remove the agent or desk under the cursor")
	map("?", M.help, "All keys")
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

-- "wide" (three columns), "compact" (one narrow column for both panels) or
-- "phone" (everything stacked at full width).
local function layout()
	if vim.o.columns < config.phone_below then
		return "phone"
	end
	return vim.o.columns < config.compact_below and "compact" or "wide"
end

-- Panel widths for the current screen.
local function panel_widths()
	local mode = layout()
	if mode == "wide" then
		return config.sidebar_width, config.changes_width
	elseif mode == "phone" then
		return vim.o.columns, vim.o.columns
	end
	local w = math.max(18, math.min(config.sidebar_width, math.floor(vim.o.columns * 0.34)))
	return w, w
end

-- Phone layout heights: the tabs take a third, the changes panel folds to
-- its header line unless it has focus.
phone_heights = function()
	if not (hub_open() and S.layout == "phone") then
		return
	end
	-- Phone: one panel at a time, picked in the tab bar at the top (Agent /
	-- Agents / Changes) or by moving into it; the others fold away.
	local current = vim.api.nvim_get_current_win()
	S.phone_view = current == S.wins.list and "agents" or current == S.wins.changes and "changes" or "agent"
	local shown = ({ agent = S.wins.term, agents = S.wins.list, changes = S.wins.changes })[S.phone_view]
	-- The tab bar is the shown panel's winbar (the tabline belongs to the
	-- bufferline plugin); folded panels get none, so nothing doubles up.
	local bar = "%!v:lua.require'agents'.phone_tabline()"
	for _, win in ipairs({ S.wins.list, S.wins.term, S.wins.changes }) do
		vim.wo[win].winfixheight = false
		local want = win == shown and bar or ""
		if vim.wo[win].winbar ~= want then
			vim.wo[win].winbar = want
		end
		if win ~= shown and vim.api.nvim_win_get_height(win) ~= 0 then
			vim.api.nvim_win_set_height(win, 0)
		end
	end
	-- Space freed above goes to a neighbour; hand all of it to the shown panel.
	vim.api.nvim_win_set_height(shown, vim.o.lines)
	if shown ~= S.wins.term then
		-- Folded, the panel scrolled to its cursor; show it from the top.
		vim.api.nvim_win_call(shown, function()
			if vim.fn.line("$") <= vim.api.nvim_win_get_height(0) then
				vim.fn.winrestview({ topline = 1 })
			end
		end)
	end
end

-- The phone tab bar, shown as the open panel's winbar.
function M.phone_tabline()
	local width = vim.o.columns
	local agent = selected_agent()
	local info = agent and S.changes[agent.cwd]
	local segments = {
		{ "agent", agent and display_name(agent) or "Agent" },
		{ "agents", "Agents " .. #S.agents },
		{ "changes", "Changes" .. (info and (" " .. #info.files) or "") },
	}
	local each = math.floor(width / #segments)
	local out = {}
	for i, seg in ipairs(segments) do
		local w = i == #segments and width - each * (#segments - 1) or each
		local label = seg[2]
		if vim.fn.strdisplaywidth(label) > w - 2 then
			label = vim.fn.strcharpart(label, 0, w - 3) .. "…"
		end
		local pad = w - vim.fn.strdisplaywidth(label)
		local left = math.floor(pad / 2)
		local hl = S.phone_view == seg[1] and "%#AgentsSegmentOn#" or "%#AgentsSegment#"
		table.insert(out, ("%%%d@v:lua.AgentsPhoneTab@%s%s%s%s%%X"):format(i, hl, (" "):rep(left), label:gsub("%%", "%%%%"), (" "):rep(pad - left)))
	end
	return table.concat(out) .. "%#AgentsSegmentBar#"
end

-- A tap on the tab bar: open that panel.
function _G.AgentsPhoneTab(index)
	if not hub_open() then
		return
	end
	local win = ({ S.wins.term, S.wins.list, S.wins.changes })[index]
	if win then
		vim.cmd.stopinsert()
		vim.api.nvim_set_current_win(win)
		if win == S.wins.term then
			-- Straight to typing into the agent.
			vim.cmd.startinsert()
		end
	end
end

-- Folded panels are 0 rows tall, which needs winminheight 0 while the hub
-- tab is current in the phone layout.
local saved_minheight
local function phone_tabline_on(on)
	if on and not saved_minheight then
		saved_minheight = vim.o.winminheight
		vim.o.winminheight = 0
	elseif not on and saved_minheight then
		vim.o.winminheight = saved_minheight
		saved_minheight = nil
	end
end

function M.open()
	if not tmux.available() then
		vim.notify("The agent hub needs tmux (brew install tmux / apt install tmux).", vim.log.levels.ERROR, { title = "Agents" })
		return
	end
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
	S.wins.term = C.fresh_window()

	S.layout = layout()
	vim.cmd(S.layout == "phone" and "topleft split" or "topleft vsplit")
	S.wins.list = vim.api.nvim_get_current_win()
	local list_buf = panel_buf("list", "agentlist")
	vim.api.nvim_win_set_buf(S.wins.list, list_buf)

	local list_width, changes_width = panel_widths()
	set_panel_win_options(S.wins.list, list_width)
	if S.layout == "compact" then
		vim.cmd("belowright split")
	else
		vim.api.nvim_set_current_win(S.wins.term)
		vim.cmd(S.layout == "phone" and "botright split" or "botright vsplit")
	end
	S.wins.changes = vim.api.nvim_get_current_win()
	local changes_buf = panel_buf("changes", "agentchanges")
	vim.api.nvim_win_set_buf(S.wins.changes, changes_buf)
	set_panel_win_options(S.wins.changes, changes_width)
	if S.layout == "compact" then
		vim.api.nvim_win_set_height(S.wins.list, math.floor(vim.o.lines * 0.55))
	elseif S.layout == "phone" then
		for _, win in ipairs({ S.wins.list, S.wins.changes }) do
			vim.wo[win].winfixwidth = false
		end
		phone_tabline_on(true)
		vim.api.nvim_set_current_win(S.wins.term)
		phone_heights()
	else
		phone_tabline_on(false)
	end

	if not vim.b[list_buf].agents_mapped then
		map_list(list_buf)
		map_changes(changes_buf)
		vim.b[list_buf].agents_mapped = true
	end

	show_agent(S.selected, false)
	if vim.api.nvim_buf_is_valid(scratch) and scratch ~= vim.api.nvim_win_get_buf(S.wins.term) then
		pcall(vim.api.nvim_buf_delete, scratch, { force = true })
	end
	vim.api.nvim_set_current_win(S.layout == "phone" and S.wins.term or S.wins.list)

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

-- Internal API for agents.flow.
M._hub = {
	S = S,
	selected_agent = selected_agent,
	select_agent = select_agent,
	status_of = status_of,
	agent_label = agent_label,
	display_name = display_name,
	poll = poll,
	refresh_changes = function()
		refresh_changes()
	end,
	pick = pick,
	choose_command = choose_command,
	create_agent = create_agent,
	note_sent = function(name, text)
		note_sent(name, text)
	end,
	find_projects = find_projects,
	open = function()
		M.open()
	end,
}

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	set_highlights()
	flow.setup(M._hub)
	wowo.setup(config.wowo)
	handoff.setup(M._hub, config.handoff)
	queue.setup(M._hub)

	local group = vim.api.nvim_create_augroup("Agents", { clear = true })
	flow.track_focus(group)
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
			if not hub_open() then
				return
			end
			-- Crossing the compact width (a phone attaching) needs the other layout.
			if layout() ~= S.layout then
				local current = vim.api.nvim_get_current_tabpage()
				local here = current == S.tab
				M.close()
				M.open()
				if not here and vim.api.nvim_tabpage_is_valid(current) then
					vim.api.nvim_set_current_tabpage(current)
				end
				return
			end
			if S.layout == "phone" then
				phone_heights()
			else
				local list_width, changes_width = panel_widths()
				vim.api.nvim_win_set_width(S.wins.list, list_width)
				vim.api.nvim_win_set_width(S.wins.changes, changes_width)
			end
			render_list()
			render_changes()
		end,
	})
	-- Phone layout: the changes panel opens up while it has focus.
	vim.api.nvim_create_autocmd("WinEnter", {
		group = group,
		callback = function()
			if S.layout == "phone" and vim.api.nvim_get_current_tabpage() == S.tab then
				phone_heights()
			end
		end,
	})
	vim.api.nvim_create_autocmd("TabEnter", {
		group = group,
		callback = function()
			phone_tabline_on(S.layout == "phone" and vim.api.nvim_get_current_tabpage() == S.tab)
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
	vim.api.nvim_create_user_command("AgentsWorkspace", function()
		M.workspace()
	end, { desc = "Open the selected agent's folder as a workspace tab" })
	vim.api.nvim_create_user_command("AgentsQueue", queue.open, { desc = "Autopilot: queue prompts per agent" })
	vim.api.nvim_create_user_command("AgentsQueueStop", queue.stop_all, { desc = "Autopilot: stop every queue" })
	vim.api.nvim_create_user_command("AgentsHandoff", handoff.handoff_selected, { desc = "Continue the selected agent's work in another CLI" })
	vim.api.nvim_create_user_command("AgentsGrid", function()
		require("agents.grid").toggle()
	end, { desc = "Mission control: every agent's screen in a grid" })
	vim.api.nvim_create_user_command("AgentsMonitor", function()
		require("agents.monitor").open()
	end, { desc = "Usage analytics for every agent CLI" })
	vim.api.nvim_create_user_command("AgentsWowo", function(opts)
		if opts.args == "check" then
			wowo.check()
		elseif wowo.prepare() then
			vim.notify(
				"wowo ready: " .. (wowo.default_model() or "no model") .. "\nhome: " .. vim.fn.fnamemodify(wowo.agent_dir(), ":~"),
				vim.log.levels.INFO,
				{ title = "WOWO-AGENT" }
			)
		end
	end, {
		nargs = "?",
		complete = function()
			return { "check" }
		end,
		desc = "wowo: write its config (check: call each provider and list its models)",
	})
	local hook_agents = { "claude", "omp", "pi", "opencode", "codex", "hermes" }
	local function only(opts)
		return #opts.fargs > 0 and opts.fargs or nil
	end
	vim.api.nvim_create_user_command("AgentsInstallHooks", function(opts)
		require("agents.hooks").install(only(opts))
	end, {
		nargs = "*",
		complete = function()
			return hook_agents
		end,
		desc = "Install the hooks that report agent status to the hub (all agents, or the ones named)",
	})
	vim.api.nvim_create_user_command("AgentsUninstallHooks", function(opts)
		require("agents.hooks").uninstall(only(opts))
	end, {
		nargs = "*",
		complete = function()
			return hook_agents
		end,
		desc = "Remove the hub's agent hooks (all agents, or the ones named)",
	})
	vim.api.nvim_create_user_command("AgentsBrowser", M.browser, { desc = "Open the web result in terminal-browser" })
	vim.api.nvim_create_user_command("AgentsSend", M.send, { range = true, desc = "Send file reference to agent" })

	vim.keymap.set("n", "<leader>mm", M.toggle, { desc = "Agents: toggle hub" })
	vim.keymap.set("n", "<leader>mn", M.new_agent, { desc = "Agents: new desk" })
	vim.keymap.set("n", "<leader>mt", M.new_tab, { desc = "Agents: new tab in desk" })
	vim.keymap.set("n", "<leader>mj", M.jump, { desc = "Agents: jump to tab" })
	vim.keymap.set("n", "<leader>mo", M.office, { desc = "Agents: office view" })
	vim.keymap.set("n", "<leader>mp", flow.prompt, { desc = "Agents: prompt the selected agent" })
	vim.keymap.set("n", "<leader>mf", flow.find, { desc = "Agents: find a tab" })
	vim.keymap.set("n", "<leader>mF", flow.fanout, { desc = "Agents: fan out a prompt to worktrees" })
	vim.keymap.set("n", "<leader>me", function()
		M.workspace()
	end, { desc = "Agents: open the agent's folder as a workspace" })
	vim.keymap.set("n", "<leader>mq", queue.open, { desc = "Agents: autopilot prompt queue" })
	vim.keymap.set("n", "<leader>mh", handoff.handoff_selected, { desc = "Agents: hand off to another agent CLI" })
	vim.keymap.set("n", "<leader>mc", function()
		require("agents.grid").toggle()
	end, { desc = "Agents: mission control grid" })
	vim.keymap.set("n", "<leader>ma", function()
		require("agents.monitor").open()
	end, { desc = "Agents: usage monitor" })
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
