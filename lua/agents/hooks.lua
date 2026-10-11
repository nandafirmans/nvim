-- Installs the Claude Code hooks that report agent state to the hub
-- (lua/agents/hooks/claude-state.sh) into ~/.claude/settings.json.
-- Without them the hub still works, but guesses Claude's status from its
-- screen output and shows no activity text.
local M = {}

-- Hook event -> argument for claude-state.sh, and the matcher it needs.
local EVENTS = {
	{ event = "SessionStart", arg = "idle", matcher = "*" },
	{ event = "UserPromptSubmit", arg = "prompt" },
	{ event = "PreToolUse", arg = "tool", matcher = "*" },
	{ event = "PostToolUse", arg = "running", matcher = "*" },
	{ event = "Notification", arg = "waiting", matcher = "permission_prompt" },
	{ event = "Stop", arg = "done" },
}

-- Commands of earlier installs, removed before installing so nothing doubles.
local OLD_SCRIPTS = { "claude-state.sh", "nvim-agents-state.sh" }

local function script_path()
	local path = vim.fn.stdpath("config") .. "/lua/agents/hooks/claude-state.sh"
	local home = vim.uv.os_homedir()
	if path:sub(1, #home + 1) == home .. "/" then
		return "$HOME" .. path:sub(#home + 1)
	end
	return path
end

local function settings_path()
	return vim.fn.expand("~/.claude/settings.json")
end

-- Edits settings.json with python3 so the file keeps its 2-space layout
-- (vim.json.encode cannot pretty-print). A copy is kept next to it.
local EDIT = [[
import json, os, shutil, sys

path, mode, script = sys.argv[1], sys.argv[2], sys.argv[3]
events = json.loads(sys.argv[4])
old = json.loads(sys.argv[5])

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

local function edit(mode)
	if vim.fn.executable("python3") == 0 then
		vim.notify("python3 is needed to edit ~/.claude/settings.json", vim.log.levels.ERROR, { title = "Agents" })
		return false
	end
	local result = vim.system({
		"python3",
		"-c",
		EDIT,
		settings_path(),
		mode,
		script_path(),
		vim.json.encode(EVENTS),
		vim.json.encode(OLD_SCRIPTS),
	}, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify("Could not update ~/.claude/settings.json:\n" .. (result.stderr or ""), vim.log.levels.ERROR, { title = "Agents" })
		return false
	end
	return true
end

function M.install()
	if edit("install") then
		vim.notify(
			"Claude hooks installed in ~/.claude/settings.json (backup: settings.json.bak-agents).\n"
				.. "They apply to Claude sessions started from now on; restart running agents with R.",
			vim.log.levels.INFO,
			{ title = "Agents" }
		)
	end
end

function M.uninstall()
	if edit("uninstall") then
		vim.notify("Claude hooks removed from ~/.claude/settings.json", vim.log.levels.INFO, { title = "Agents" })
	end
end

return M
