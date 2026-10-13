-- Prompt box: a multi-line float for writing a prompt to an agent, with
-- completion like the agent's own input: "/" lists that CLI's slash
-- commands, skills and custom commands (user, project and plugin ones),
-- "@" lists the project's files. Uses nvim-cmp when installed, else
-- <C-x><C-u>. ⏎ sends, Ctrl-j adds a line, Esc then q (or Esc Esc) cancels.
local M = {}

-- Built-in slash commands per CLI (the common ones).
local BUILTIN = {
	claude = {
		{ "clear", "Clear the conversation" },
		{ "compact", "Compact the conversation to free context" },
		{ "context", "Show context window use" },
		{ "cost", "Show token use and cost" },
		{ "usage", "Show plan usage limits" },
		{ "model", "Switch model" },
		{ "resume", "Resume an earlier conversation" },
		{ "rewind", "Rewind the conversation or code" },
		{ "review", "Review a pull request" },
		{ "init", "Write a CLAUDE.md for this project" },
		{ "memory", "Edit memory files" },
		{ "agents", "Manage subagents" },
		{ "mcp", "Manage MCP servers" },
		{ "hooks", "Manage hooks" },
		{ "permissions", "Manage tool permissions" },
		{ "config", "Open settings" },
		{ "status", "Show version, model and account" },
		{ "export", "Export the conversation" },
		{ "add-dir", "Add a working directory" },
		{ "plugin", "Manage plugins" },
		{ "doctor", "Check the installation" },
		{ "help", "Show help" },
	},
	omp = {
		{ "model", "Switch model" },
		{ "new", "Start a new session" },
		{ "resume", "Resume a session" },
		{ "compact", "Compact the conversation" },
		{ "tree", "Session tree" },
		{ "session", "Session info" },
		{ "settings", "Settings" },
		{ "export", "Export the session" },
		{ "hotkeys", "Show hotkeys" },
	},
	opencode = {
		{ "new", "Start a new session" },
		{ "sessions", "List sessions" },
		{ "models", "Switch model" },
		{ "compact", "Compact the session" },
		{ "undo", "Undo the last change" },
		{ "redo", "Redo" },
		{ "share", "Share the session" },
		{ "init", "Write AGENTS.md" },
		{ "export", "Export the session" },
		{ "help", "Show help" },
	},
	codex = {
		{ "model", "Switch model" },
		{ "approvals", "Approval mode" },
		{ "new", "Start a new conversation" },
		{ "init", "Write AGENTS.md" },
		{ "compact", "Compact the conversation" },
		{ "diff", "Show the git diff" },
		{ "review", "Review changes" },
		{ "status", "Show status" },
	},
	hermes = {
		{ "help", "Show help" },
		{ "new", "Start a new session" },
		{ "model", "Switch model" },
		{ "skills", "List skills" },
	},
}
BUILTIN.pi = BUILTIN.omp

local function read_description(path)
	local ok, lines = pcall(vim.fn.readfile, path, "", 40)
	if not ok then
		return ""
	end
	local in_front = false
	for i, line in ipairs(lines) do
		if i == 1 and line == "---" then
			in_front = true
		elseif in_front and line == "---" then
			break
		elseif in_front then
			local desc = line:match("^description:%s*(.+)$")
			if desc then
				return (desc:gsub("^[\"']", ""):gsub("[\"']$", ""))
			end
		end
	end
	return ""
end

-- Only ~ is expanded here; the wildcards are left for glob().
local function glob(pattern)
	local home = vim.uv.os_homedir()
	return vim.fn.glob((pattern:gsub("^~", home)), false, true)
end

-- name -> description, from skill folders (SKILL.md) and command files (*.md).
local function scan(out, skills, commands, prefix)
	for _, pattern in ipairs(skills or {}) do
		for _, file in ipairs(glob(pattern .. "/*/SKILL.md")) do
			local name = (prefix or "") .. vim.fs.basename(vim.fs.dirname(file))
			out[name] = out[name] or read_description(file)
		end
	end
	for _, pattern in ipairs(commands or {}) do
		for _, file in ipairs(glob(pattern .. "/*.md")) do
			local name = (prefix or "") .. vim.fs.basename(file):gsub("%.md$", "")
			out[name] = out[name] or read_description(file)
		end
	end
end

local cache = {}

-- Slash entries { name, description, kind } for a CLI in a folder.
function M.slash_items(tool, cwd)
	local key = tool .. "|" .. (cwd or "")
	local entry = cache[key]
	if entry and os.time() - entry.at < 30 then
		return entry.items
	end
	local found = {}
	if tool == "claude" then
		scan(found, { "~/.claude/skills", cwd .. "/.claude/skills" }, { "~/.claude/commands", cwd .. "/.claude/commands" })
		-- Plugin skills and commands appear as plugin:name.
		for _, dir in ipairs(glob("~/.claude/plugins/cache/*/*")) do
			local plugin = vim.fs.basename(dir)
			local versions = glob(dir .. "/*")
			table.sort(versions)
			local latest = versions[#versions]
			if latest then
				scan(found, { latest .. "/skills" }, { latest .. "/commands" }, plugin .. ":")
			end
		end
	elseif tool == "omp" or tool == "pi" then
		scan(found, nil, { "~/.pi/agent/prompts", "~/.omp/agent/prompts", cwd .. "/.pi/prompts", cwd .. "/.omp/prompts" })
		scan(found, { "~/.pi/agent/skills", "~/.omp/agent/skills", cwd .. "/.pi/skills" }, nil, "skill:")
	elseif tool == "opencode" then
		scan(found, nil, { "~/.config/opencode/command", "~/.config/opencode/commands", cwd .. "/.opencode/command", cwd .. "/.opencode/commands" })
	elseif tool == "codex" then
		scan(found, nil, { "~/.codex/prompts" }, "prompts:")
	elseif tool == "hermes" then
		scan(found, { "~/.hermes/skills" }, nil)
	end
	local items = {}
	for name, desc in pairs(found) do
		table.insert(items, { name = name, description = desc, kind = "skill" })
	end
	table.sort(items, function(a, b)
		return a.name < b.name
	end)
	for _, b in ipairs(BUILTIN[tool] or {}) do
		table.insert(items, { name = b[1], description = b[2], kind = "builtin" })
	end
	cache[key] = { at = os.time(), items = items }
	return items
end

local file_cache = {}

local function project_files(cwd)
	local entry = file_cache[cwd]
	if entry and os.time() - entry.at < 30 then
		return entry.files
	end
	local files = {}
	local ok, job = pcall(vim.system, { "git", "-C", cwd, "ls-files", "--cached", "--others", "--exclude-standard" }, { text = true })
	if ok then
		local result = job:wait(3000)
		if result.code == 0 then
			files = vim.split(result.stdout or "", "\n", { trimempty = true })
		end
	end
	file_cache[cwd] = { at = os.time(), files = files }
	return files
end

-- Completion items for the text before the cursor in a prompt buffer.
local function candidates(buf, before)
	local tool, cwd = vim.b[buf].agents_tool, vim.b[buf].agents_cwd
	local slash = before:match("^%s*(/[%w%-_:%.]*)$")
	if slash then
		local items = {}
		for _, it in ipairs(M.slash_items(tool or "claude", cwd or vim.fn.getcwd())) do
			table.insert(items, { word = "/" .. it.name, menu = it.kind, info = it.description })
		end
		return items, #before - #slash
	end
	local at = before:match("(@[%w%._/%-]*)$")
	if at and cwd then
		local items = {}
		for _, file in ipairs(project_files(cwd)) do
			table.insert(items, { word = "@" .. file, menu = "file" })
		end
		return items, #before - #at
	end
	return nil
end

-- nvim-cmp source -----------------------------------------------------------------

local source = {}
source.__index = source

function source:is_available()
	return vim.bo.filetype == "agentprompt"
end

function source:get_trigger_characters()
	return { "/", "@" }
end

function source:get_keyword_pattern()
	return [[\%([/@][[:alnum:]_:./-]*\)]]
end

function source:complete(params, callback)
	local ctx = params.context
	local items = candidates(ctx.bufnr, ctx.cursor_before_line)
	if not items then
		return callback({ items = {}, isIncomplete = false })
	end
	local kinds = require("cmp").lsp.CompletionItemKind
	local out = {}
	for _, it in ipairs(items) do
		table.insert(out, {
			label = it.word,
			insertText = it.word .. " ",
			filterText = it.word,
			kind = it.menu == "file" and kinds.File or it.menu == "skill" and kinds.Module or kinds.Keyword,
			labelDetails = { description = it.menu },
			documentation = it.info ~= "" and it.info or nil,
		})
	end
	callback({ items = out, isIncomplete = false })
end

local registered = false

local function register_cmp()
	if registered then
		return true
	end
	local ok, cmp = pcall(require, "cmp")
	if not ok then
		return false
	end
	cmp.register_source("agents_prompt", setmetatable({}, source))
	cmp.setup.filetype("agentprompt", {
		sources = cmp.config.sources({ { name = "agents_prompt" } }, { { name = "buffer" } }),
	})
	registered = true
	return true
end

-- Fallback for <C-x><C-u> without nvim-cmp.
function M.completefunc(findstart, base)
	local buf = vim.api.nvim_get_current_buf()
	local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col(".") - 1)
	local items, start = candidates(buf, before)
	if findstart == 1 then
		return items and start or -3
	end
	return vim.tbl_filter(function(it)
		return vim.startswith(it.word, base)
	end, items or {})
end

-- Box -----------------------------------------------------------------------------

-- Opens the box for `agent`; on_submit(text) gets the prompt (may be multi-line).
-- options.targets: a list of { label, agent, run = function(text) } to choose
-- from with Tab / S-Tab (options.index is the first one); the chosen target's
-- run() gets the prompt instead of on_submit, and its agent drives completion.
function M.open(agent, title, on_submit, options)
	options = options or {}
	local targets = options.targets
	local current = options.index or 1
	local has_cmp = register_cmp()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	local function set_agent(a)
		vim.b[buf].agents_tool = a and a.tool or nil
		vim.b[buf].agents_cwd = a and a.cwd or nil
	end
	local function target_title()
		local t = targets[current]
		return (" ✉ %s  ‹ %d/%d › "):format(t.label, current, #targets)
	end
	if targets then
		agent = targets[current].agent or agent
	end
	set_agent(agent)
	vim.bo[buf].filetype = "agentprompt"
	vim.bo[buf].completefunc = "v:lua.require'agents.prompt_box'.completefunc"
	local w = math.max(50, math.floor(vim.o.columns * 0.6))
	local h = 6
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = math.floor((vim.o.lines - h) / 2) - 4,
		col = math.floor((vim.o.columns - w) / 2),
		border = "rounded",
		title = targets and target_title() or (" " .. title .. " "),
		title_pos = "center",
		footer = targets and " ⏎ send · Tab next recipient · Ctrl-j new line · / commands · @ files · Esc Esc cancel "
			or " ⏎ send · Ctrl-j new line · / commands & skills · @ files · Esc Esc cancel ",
		footer_pos = "center",
	})
	vim.wo[win].wrap = true
	vim.wo[win].number = false
	vim.wo[win].signcolumn = "no"

	local done = false
	local function close()
		done = true
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		vim.cmd.stopinsert()
	end
	local function submit()
		if done then
			return
		end
		local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
		close()
		if text == "" then
			return
		end
		if targets then
			targets[current].run(text)
		else
			on_submit(text)
		end
	end

	local opts = { buffer = buf, nowait = true }
	vim.keymap.set("i", "<CR>", function()
		local ok, cmp = pcall(require, "cmp")
		if ok and cmp.visible() and cmp.get_selected_entry() then
			cmp.confirm({ select = false })
		else
			submit()
		end
	end, opts)
	vim.keymap.set("i", "<C-j>", "<CR>", { buffer = buf, remap = false })
	vim.keymap.set("n", "<CR>", submit, opts)
	vim.keymap.set("n", "q", close, opts)
	vim.keymap.set("n", "<Esc>", close, opts)
	if targets and #targets > 1 then
		local function cycle(step)
			return function()
				local ok, cmp = pcall(require, "cmp")
				if ok and cmp.visible() then
					return step > 0 and cmp.select_next_item() or cmp.select_prev_item()
				end
				current = (current - 1 + step) % #targets + 1
				set_agent(targets[current].agent or agent)
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_set_config(win, { title = target_title(), title_pos = "center" })
				end
			end
		end
		for _, mode in ipairs({ "i", "n" }) do
			vim.keymap.set(mode, "<Tab>", cycle(1), opts)
			vim.keymap.set(mode, "<S-Tab>", cycle(-1), opts)
		end
	end
	if not has_cmp then
		-- Without nvim-cmp: open the completion menu when / or @ is typed.
		for _, ch in ipairs({ "/", "@" }) do
			vim.keymap.set("i", ch, ch .. "<C-x><C-u>", { buffer = buf })
		end
	end
	vim.cmd.startinsert()
end

return M
