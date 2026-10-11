-- Installs the hooks that let each agent CLI report its state (status, task,
-- activity, session id) to the hub. One step per CLI; a CLI that is not
-- installed is skipped with a note, and a failure in one never stops the
-- others. Without its hook an agent still works in the hub, with its status
-- guessed from screen output.
--
--   Claude Code  ~/.claude/settings.json hooks        -> hooks/claude-state.sh
--   omp, pi      extension symlink                     -> hooks/omp-state.ts
--   opencode     plugin symlink                        -> hooks/opencode-state.js
--   codex        `notify` in ~/.codex/config.toml      -> hooks/codex-notify.sh
--   hermes       hooks in ~/.hermes/config.yaml        -> hooks/hermes-state.sh
local M = {}

-- The hooks/ folder next to this file, wherever the config is installed.
local HOOKS_DIR = vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)) .. "/hooks"

local function hooks_dir()
	return HOOKS_DIR
end

-- Path with $HOME, for configs that run commands through a shell.
local function home_relative(path)
	local home = vim.uv.os_homedir()
	if path:sub(1, #home + 1) == home .. "/" then
		return "$HOME" .. path:sub(#home + 1)
	end
	return path
end

local function exists(path)
	return vim.uv.fs_stat(vim.fn.expand(path)) ~= nil
end

local function has(cli, data_dir)
	return vim.fn.executable(cli) == 1 or (data_dir and exists(data_dir))
end

local function python(code, args)
	if vim.fn.executable("python3") == 0 then
		return false, "python3 is not installed"
	end
	local result = vim.system(vim.list_extend({ "python3", "-I", "-c", code }, args or {}), { text = true }):wait()
	if result.code ~= 0 then
		return false, vim.trim(result.stderr or "")
	end
	return true, vim.trim(result.stdout or "")
end

local function link(source, target)
	target = vim.fn.expand(target)
	vim.fn.mkdir(vim.fs.dirname(target), "p")
	pcall(vim.uv.fs_unlink, target)
	local ok, err = vim.uv.fs_symlink(source, target)
	if not ok then
		return false, err
	end
	return true
end

local function unlink(target)
	pcall(vim.uv.fs_unlink, vim.fn.expand(target))
end

-- Claude Code ------------------------------------------------------------------

local CLAUDE_EVENTS = {
	{ event = "SessionStart", arg = "idle", matcher = "*" },
	{ event = "UserPromptSubmit", arg = "prompt" },
	{ event = "PreToolUse", arg = "tool", matcher = "*" },
	{ event = "PostToolUse", arg = "running", matcher = "*" },
	{ event = "Notification", arg = "waiting", matcher = "permission_prompt" },
	{ event = "Stop", arg = "done" },
}
-- Commands of earlier installs, removed first so nothing doubles.
local CLAUDE_OLD = { "claude-state.sh", "nvim-agents-state.sh" }

-- Edits settings.json keeping its 2-space layout; a copy is kept next to it.
local CLAUDE_EDIT = [[
import json, os, shutil, sys

path, mode, script = sys.argv[1], sys.argv[2], sys.argv[3]
events, old = json.loads(sys.argv[4]), json.loads(sys.argv[5])

data = {}
if os.path.exists(path):
    with open(path) as f:
        text = f.read()
    data = json.loads(text) if text.strip() else {}
    shutil.copyfile(path, path + ".bak-agents")

hooks = data.setdefault("hooks", {})
for event in list(hooks):
    kept = [e for e in hooks[event]
            if not any(any(o in h.get("command", "") for o in old) for h in e.get("hooks", []))]
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]

if mode == "install":
    for spec in events:
        entry = {"hooks": [{"type": "command", "command": 'sh "%s" %s' % (script, spec["arg"]), "timeout": 5}]}
        if spec.get("matcher"):
            entry = {"matcher": spec["matcher"], **entry}
        hooks.setdefault(spec["event"], []).append(entry)

if not hooks:
    del data["hooks"]

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    f.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
]]

local function claude(mode)
	if not has("claude", "~/.claude") then
		return "skipped", "Claude Code not installed"
	end
	local ok, err = python(CLAUDE_EDIT, {
		vim.fn.expand("~/.claude/settings.json"),
		mode,
		home_relative(hooks_dir() .. "/claude-state.sh"),
		vim.json.encode(CLAUDE_EVENTS),
		vim.json.encode(CLAUDE_OLD),
	})
	if not ok then
		return "failed", err
	end
	return "done", "~/.claude/settings.json (backup: settings.json.bak-agents)"
end

-- omp, pi, opencode: files their CLIs load from a folder -----------------------

local function extension(cli, data_dir, source, target)
	return function(mode)
		if mode == "uninstall" then
			unlink(target)
			return "done", target
		end
		if not has(cli, data_dir) then
			return "skipped", cli .. " not installed"
		end
		local ok, err = link(hooks_dir() .. "/" .. source, target)
		if not ok then
			return "failed", tostring(err)
		end
		return "done", target
	end
end

-- codex: the `notify` program in config.toml -------------------------------------

-- Puts `notify` at the top of config.toml (top-level keys must precede tables).
-- An existing notify of the user's own is left alone.
local CODEX_EDIT = [[
import os, shutil, sys

path, mode, script = sys.argv[1], sys.argv[2], sys.argv[3]
marker = "codex-notify.sh"
lines = []
if os.path.exists(path):
    with open(path) as f:
        lines = f.read().splitlines()
    shutil.copyfile(path, path + ".bak-agents")

others = [l for l in lines if l.strip().startswith("notify") and "=" in l and marker not in l]
lines = [l for l in lines if not (l.strip().startswith("notify") and marker in l)]

if mode == "install":
    if others:
        print("manual: config.toml already has its own notify: " + others[0].strip())
        sys.exit(0)
    lines.insert(0, 'notify = ["sh", "%s"]' % script)

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    f.write("\n".join(lines) + "\n")
print("ok")
]]

local function codex(mode)
	if not has("codex", nil) and mode == "install" then
		return "skipped", "codex not installed"
	end
	if mode == "uninstall" and not exists("~/.codex/config.toml") then
		return "done", "nothing to remove"
	end
	local ok, out = python(CODEX_EDIT, { vim.fn.expand("~/.codex/config.toml"), mode, hooks_dir() .. "/codex-notify.sh" })
	if not ok then
		return "failed", out
	end
	if out:match("^manual:") then
		return "manual", out:sub(9) .. "; add the hub's script to it yourself: " .. hooks_dir() .. "/codex-notify.sh"
	end
	return "done", "~/.codex/config.toml (status done on turn end; backup: config.toml.bak-agents)"
end

-- hermes: shell hooks in config.yaml ----------------------------------------------

-- Line-based edit so the rest of config.yaml keeps its comments and layout.
-- Adds one list item per event under `hooks:`; uninstall removes them again.
local HERMES_EDIT = [[
import os, shutil, sys

path, mode, command = sys.argv[1], sys.argv[2], sys.argv[3]
events = sys.argv[4].split(",")
marker = "hermes-state.sh"

with open(path) as f:
    lines = f.read().splitlines()
shutil.copyfile(path, path + ".bak-agents")

def indent(line):
    return len(line) - len(line.lstrip())

# Remove items from earlier installs (the "- command:" line and its fields).
out, i = [], 0
while i < len(lines):
    line = lines[i]
    if line.lstrip().startswith("- command:") and marker in line:
        level = indent(line)
        i += 1
        while i < len(lines) and lines[i].strip() and indent(lines[i]) > level and not lines[i].lstrip().startswith("- "):
            i += 1
        continue
    out.append(line)
    i += 1
lines = out

def hooks_block():
    for n, line in enumerate(lines):
        if line.rstrip() == "hooks:":
            end = n + 1
            while end < len(lines) and (not lines[end].strip() or indent(lines[end]) > 0):
                end += 1
            return n, end
        if line.startswith("hooks:") and line.split(":", 1)[1].strip() not in ("", "{}", "null"):
            print("manual: hooks: is written inline in config.yaml")
            sys.exit(0)
    return None

# Drop the event keys this left empty (only the hub's own events).
block = hooks_block()
if block:
    start, end = block
    keep = []
    for n, line in enumerate(lines):
        if start < n < end and line.strip().rstrip(":") in events and line.rstrip().endswith(":"):
            nxt = next((l for l in lines[n + 1:end] if l.strip()), "")
            if not nxt or indent(nxt) <= indent(line):
                continue
        keep.append(line)
    lines = keep

if mode == "install":
    block = hooks_block()
    if not block:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append("hooks:")
        block = (len(lines) - 1, len(lines))
    start, end = block
    child = next((indent(l) for l in lines[start + 1:end] if l.strip()), 2)
    for event in events:
        item = [" " * (child + 2) + "- command: " + command, " " * (child + 4) + "timeout: 5"]
        start, end = hooks_block()
        key = next((n for n in range(start + 1, end) if lines[n].strip() == event + ":" and indent(lines[n]) == child), None)
        if key is None:
            at = end
            while at > start + 1 and not lines[at - 1].strip():
                at -= 1
            lines[at:at] = [" " * child + event + ":"] + item
        else:
            at = key + 1
            while at < end and (not lines[at].strip() or indent(lines[at]) > child):
                at += 1
            while at > key + 1 and not lines[at - 1].strip():
                at -= 1
            lines[at:at] = item

with open(path, "w") as f:
    f.write("\n".join(lines) + "\n")
print("ok")
]]

local HERMES_EVENTS = {
	"on_session_start",
	"pre_llm_call",
	"pre_tool_call",
	"pre_approval_request",
	"post_approval_response",
	"on_session_end",
}

-- Parses config.yaml with Hermes's own Python (it has PyYAML), so a broken
-- edit is caught and rolled back.
local function hermes_yaml_ok(path)
	local py = vim.fn.expand("~/.hermes/hermes-agent/venv/bin/python")
	if vim.fn.executable(py) == 0 then
		return true
	end
	local result = vim.system({ py, "-c", "import sys, yaml; yaml.safe_load(open(sys.argv[1]))", path }):wait()
	return result.code == 0
end

local function hermes(mode)
	local config = vim.fn.expand("~/.hermes/config.yaml")
	if not exists(config) then
		if mode == "install" and vim.fn.executable("hermes") == 1 then
			return "manual", "run `hermes setup` first; ~/.hermes/config.yaml does not exist yet"
		end
		return mode == "install" and "skipped" or "done", mode == "install" and "hermes not installed" or "nothing to remove"
	end
	local command = "sh " .. hooks_dir() .. "/hermes-state.sh"
	local ok, out = python(HERMES_EDIT, { config, mode, command, table.concat(HERMES_EVENTS, ",") })
	if not ok then
		return "failed", out
	end
	if out:match("^manual:") then
		return "manual", out:sub(9)
	end
	if not hermes_yaml_ok(config) then
		vim.uv.fs_copyfile(config .. ".bak-agents", config)
		return "failed", "the edited config.yaml did not parse; restored the backup"
	end
	return "done", "~/.hermes/config.yaml (backup: config.yaml.bak-agents; hermes may ask once to allow the hook)"
end

-- Install / uninstall -------------------------------------------------------------

local STEPS = {
	{ "claude", claude },
	{ "omp", extension("omp", "~/.omp", "omp-state.ts", "~/.omp/agent/extensions/nvim-agents-state.ts") },
	{ "pi", extension("pi", "~/.pi/agent", "omp-state.ts", "~/.pi/agent/extensions/nvim-agents-state.ts") },
	{ "opencode", extension("opencode", "~/.config/opencode", "opencode-state.js", "~/.config/opencode/plugins/nvim-agents-state.js") },
	{ "codex", codex },
	{ "hermes", hermes },
}

local LABELS = { done = "✓", skipped = "–", manual = "!", failed = "✗" }

-- `only`: a list of agent names to limit the run to (default: all).
local function run(mode, only)
	local lines, worst = {}, vim.log.levels.INFO
	for _, step in ipairs(STEPS) do
		if only and not vim.tbl_contains(only, step[1]) then
			goto continue
		end
		local ok, status, detail = pcall(step[2], mode)
		if not ok then
			status, detail = "failed", tostring(status)
		end
		if status == "failed" or status == "manual" then
			worst = vim.log.levels.WARN
		end
		table.insert(lines, ("%s %-9s %s"):format(LABELS[status] or "?", step[1], detail or ""))
		::continue::
	end
	local title = mode == "install" and "Agent hooks installed" or "Agent hooks removed"
	local footer = mode == "install" and "\nThey apply to agents started from now on; restart running tabs with R." or ""
	vim.notify(table.concat(lines, "\n") .. footer, worst, { title = title })
end

-- :AgentsInstallHooks [agent ...]
function M.install(only)
	run("install", only)
end

function M.uninstall(only)
	run("uninstall", only)
end

return M
