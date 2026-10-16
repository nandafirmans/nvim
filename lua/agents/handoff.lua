-- Handoff: when an agent hits its usage limit, continue the work in another
-- agent CLI, in the same folder (or worktree). The new agent starts with a
-- brief: the task, the recent requests and last report from the old
-- agent's transcript, and the files changed so far. With auto handoff
-- (default: claude -> omp, omp -> claude), a limited agent hands off by
-- itself; when the partner is limited too, it stops and tells you.
local tmux = require("agents.tmux")
local usage = require("agents.usage")

local M = {}

local hub
local config = {
	auto = true,
	partners = { claude = "omp", omp = "claude" },
	-- How long a CLI counts as limited after one of its tabs hit the limit.
	limited_for = 3 * 3600,
}

-- tool -> { at, message }: the last time a tab of that CLI hit its limit.
local limited_tools = {}
-- agent name -> true once it has been handed off (or stopped), so it is
-- handled once per limit.
local handled = {}

function M.setup(api, opts)
	hub = api
	config = vim.tbl_deep_extend("force", config, opts or {})
end

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Agents · handoff" })
end

-- Detection -------------------------------------------------------------------

-- Usage-limit messages as CLIs print them, e.g. Claude's "You've hit your
-- session limit · resets 1:30am", opencode's "monthly usage limit reached",
-- OpenAI's "You've hit your usage limit".
local PATTERNS = {
	"hit your [%w%-]* ?limit",
	"usage limit reached",
	"usage limit has been reached",
	"limit reached.*reset",
	"limit will reset",
	"rate limit exceeded",
	"rate_limit_error",
	"insufficient_quota",
	"quota exceeded",
	"out of credits",
	"credit balance is too low",
	"exceeded your current quota",
}

-- The limit message in a block of text, or nil.
function M.limit_message(text)
	local lower = text:lower()
	for _, pattern in ipairs(PATTERNS) do
		local s = lower:find(pattern)
		if s then
			-- Return the whole line it is on, as the agent printed it.
			local line_start = text:sub(1, s):match(".*()\n") or 1
			local line_end = text:find("\n", s) or (#text + 1)
			return (vim.trim(text:sub(line_start, line_end - 1)):gsub("^[^%w]+", ""))
		end
	end
end

-- Checks the bottom of an idle agent's screen for a limit message. Only the
-- last few lines count, so a limit mentioned earlier in the conversation
-- (or code about rate limiting) does not trigger it.
function M.check_screen(agent, cb)
	tmux.run({ "capture-pane", "-p", "-J", "-t", "=" .. agent.name .. ":" }, function(result)
		if result.code ~= 0 then
			return cb(nil)
		end
		local lines = {}
		for line in vim.gsplit(result.stdout or "", "\n") do
			if vim.trim(line) ~= "" then
				table.insert(lines, line)
			end
		end
		local tail = table.concat(vim.list_slice(lines, math.max(1, #lines - 8), #lines), "\n")
		cb(M.limit_message(tail))
	end)
end

function M.tool_limited(tool)
	local entry = limited_tools[tool]
	return entry and (os.time() - entry.at) < config.limited_for and entry or nil
end

-- Transcripts -------------------------------------------------------------------

local function read_lines(path, max_bytes)
	local file = path and io.open(path, "rb")
	if not file then
		return {}
	end
	local size = file:seek("end")
	file:seek("set", math.max(0, size - (max_bytes or 1024 * 1024)))
	local data = file:read("*a")
	file:close()
	return vim.split(data, "\n", { trimempty = true })
end

local function text_of(content)
	if type(content) == "string" then
		return content
	end
	local parts = {}
	for _, part in ipairs(type(content) == "table" and content or {}) do
		if type(part) == "table" and part.type == "text" and type(part.text) == "string" then
			table.insert(parts, part.text)
		end
	end
	return table.concat(parts, "\n")
end

-- omp keeps sessions in ~/.omp/agent/sessions/-<cwd under home, / as ->/<ts>_<id>.jsonl
-- (pi in ~/.pi/agent, wowo in its own home).
local function omp_transcript(agent)
	local home = vim.uv.os_homedir()
	local rel = agent.cwd:sub(1, #home) == home and agent.cwd:sub(#home + 1) or agent.cwd
	local agent_dir = agent.tool == "wowo" and require("agents.wowo").agent_dir()
		or vim.fn.expand(agent.tool == "pi" and "~/.pi/agent" or "~/.omp/agent")
	local dir = agent_dir .. "/sessions/" .. rel:gsub("/", "-")
	local newest, newest_time
	for name, kind in vim.fs.dir(dir) do
		if kind == "file" and name:match("%.jsonl$") then
			if agent.session_id and name:find(agent.session_id, 1, true) then
				return dir .. "/" .. name
			end
			local stat = vim.uv.fs_stat(dir .. "/" .. name)
			if stat and (not newest_time or stat.mtime.sec > newest_time) then
				newest, newest_time = dir .. "/" .. name, stat.mtime.sec
			end
		end
	end
	return newest
end

-- Recent user requests and the last assistant report from a transcript.
local function conversation(agent, keep)
	local path, role_of
	if agent.tool == "claude" then
		path = usage.transcript(agent)
		role_of = function(d)
			if d.type == "user" and type(d.message) == "table" and type(d.message.content) == "string" then
				return "user", d.message.content
			elseif d.type == "assistant" and type(d.message) == "table" and d.message.model ~= "<synthetic>" then
				return "assistant", text_of(d.message.content)
			end
		end
	elseif agent.tool == "omp" or agent.tool == "pi" or agent.tool == "wowo" then
		path = omp_transcript(agent)
		role_of = function(d)
			local m = d.type == "message" and type(d.message) == "table" and d.message
			if m and (m.role == "user" or m.role == "assistant") then
				return m.role, text_of(m.content)
			end
		end
	end
	local requests, report = {}, nil
	for _, line in ipairs(read_lines(path)) do
		local ok, d = pcall(vim.json.decode, line)
		if ok and type(d) == "table" then
			local role, text = role_of(d)
			text = text and vim.trim(text) or ""
			if role == "user" and text ~= "" and not text:match("^<") then
				table.insert(requests, text)
			elseif role == "assistant" and text ~= "" then
				report = text
			end
		end
	end
	keep = keep or 5
	return vim.list_slice(requests, math.max(1, #requests - keep + 1), #requests), report
end

-- Prompts the user typed to this agent (newest last), from its transcript;
-- cached for a few seconds since views redraw often.
local history_cache = {}
function M.typed_prompts(agent, limit)
	local key = agent.name .. (agent.session_id or agent.claude_session or "")
	local entry = history_cache[key]
	if not entry or os.time() - entry.at >= 5 then
		local ok, requests = pcall(conversation, agent, 50)
		entry = { at = os.time(), list = ok and requests or {} }
		history_cache[key] = entry
	end
	return vim.list_slice(entry.list, math.max(1, #entry.list - (limit or 5) + 1), #entry.list)
end

local function git(cwd, args)
	local ok, job = pcall(vim.system, vim.list_extend({ "git", "-C", cwd }, args), { text = true })
	if not ok then
		return ""
	end
	local result = job:wait(5000)
	return result.code == 0 and vim.trim(result.stdout or "") or ""
end

local function clip(text, max)
	if #text <= max then
		return text
	end
	return text:sub(1, max) .. "\n[…truncated]"
end

-- The first prompt for the agent that takes over.
function M.brief(agent, reason)
	local requests, report = conversation(agent)
	local out = {
		("You are taking over a coding task from another agent (%s) that stopped: %s."):format(agent.tool, reason),
		"Continue the work in this repository. Do not start over: inspect what is already done (git status, git diff), then finish the remaining steps and verify them.",
		"",
		"## Task",
		agent.task or (requests[1] and clip(requests[1], 600)) or "(not recorded)",
	}
	if #requests > 0 then
		vim.list_extend(out, { "", "## Recent requests from the user, oldest first" })
		for _, r in ipairs(requests) do
			table.insert(out, "- " .. clip(r:gsub("\n+", " "), 500))
		end
	end
	if report then
		vim.list_extend(out, { "", "## Last report from the previous agent", clip(report, 2000) })
	end
	local branch = git(agent.cwd, { "rev-parse", "--abbrev-ref", "HEAD" })
	local status = git(agent.cwd, { "status", "--short" })
	local log = git(agent.cwd, { "log", "--oneline", "-5" })
	vim.list_extend(out, { "", "## Repository state", "Branch: " .. (branch ~= "" and branch or "(none)") })
	if status ~= "" then
		vim.list_extend(out, { "Uncommitted changes (git status --short):", clip(status, 1200) })
	else
		table.insert(out, "No uncommitted changes.")
	end
	if log ~= "" then
		vim.list_extend(out, { "Recent commits:", log })
	end
	return table.concat(out, "\n")
end

-- Handoff ---------------------------------------------------------------------

local function installed(tool)
	if tool == "wowo" then
		return require("agents.wowo").available()
	end
	return vim.fn.executable(tool) == 1
end

-- Starts `target` in the agent's desk and folder with the brief as its first prompt.
function M.handoff(agent, target, reason)
	if not installed(target) then
		notify(target .. " is not installed; cannot hand off " .. hub.agent_label(agent), vim.log.levels.WARN)
		return
	end
	if target == "wowo" and not require("agents.wowo").prepare() then
		return
	end
	local brief = M.brief(agent, reason or "handed off by you")
	local base = target == "wowo" and require("agents.wowo").command() or target
	local command = require("agents.flow").first_prompt_command(target, base, brief)
	local name = hub.create_agent({
		project = agent.project,
		cwd = agent.cwd,
		tool = target,
		command = command,
		branch = agent.branch,
		label = target .. " ← " .. hub.display_name(agent),
		focus = false,
	})
	if not name then
		return
	end
	handled[agent.name] = true
	tmux.set_option(agent.name, "activity", "handed off to " .. target)
	tmux.set_option(name, "handoff_from", agent.tool)
	notify(("%s → continued in %s"):format(hub.agent_label(agent), target))
	require("agents.flow").system_notify(agent.project, ("%s handed off to %s"):format(hub.display_name(agent), target))
	return name
end

-- Manual handoff of the selected agent: pick the CLI to continue in.
function M.handoff_selected()
	local agent = hub.selected_agent()
	if not agent then
		return
	end
	local targets = vim.tbl_filter(function(tool)
		return tool ~= agent.tool and installed(tool)
	end, { "claude", "omp", "wowo", "opencode", "codex", "pi", "hermes" })
	if #targets == 0 then
		notify("No other agent CLI installed to hand off to", vim.log.levels.WARN)
		return
	end
	local partner = config.partners[agent.tool]
	table.sort(targets, function(a, b)
		return a == partner and b ~= partner
	end)
	hub.pick(targets, { prompt = "Continue " .. hub.display_name(agent) .. " in" }, function(target)
		if target then
			M.handoff(agent, target, "handed off by the user")
		end
	end)
end

-- Called when an agent is found at its usage limit.
function M.on_limited(agent, message)
	local first = not limited_tools[agent.tool] or limited_tools[agent.tool].message ~= message
	limited_tools[agent.tool] = { at = os.time(), message = message }
	if handled[agent.name] then
		return
	end
	local partner = config.partners[agent.tool]
	if not config.auto or not partner then
		handled[agent.name] = true
		if first then
			notify(("%s hit its limit: %s\nPress H to hand it off."):format(hub.agent_label(agent), message), vim.log.levels.WARN)
		end
		return
	end
	if not installed(partner) then
		handled[agent.name] = true
		notify(("%s hit its limit and %s is not installed: %s"):format(hub.agent_label(agent), partner, message), vim.log.levels.WARN)
		return
	end
	local partner_limit = M.tool_limited(partner)
	if partner_limit then
		-- Both sides are out: stop rather than bounce the task back and forth.
		handled[agent.name] = true
		local msg = ("Both %s and %s hit their limits; stopped.\n%s: %s\n%s: %s"):format(
			agent.tool,
			partner,
			agent.tool,
			message,
			partner,
			partner_limit.message
		)
		notify(msg, vim.log.levels.ERROR)
		require("agents.flow").system_notify(agent.project, ("Both %s and %s hit their limits"):format(agent.tool, partner))
		return
	end
	M.handoff(agent, partner, "it hit its usage limit (" .. message .. ")")
end

-- An agent that works again is no longer limited, and neither is its CLI.
function M.clear(agent)
	handled[agent.name] = nil
	limited_tools[agent.tool] = nil
end

return M
