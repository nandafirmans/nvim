#!/bin/sh
# Reports Claude Code state to the Neovim agent hub (lua/agents).
# Installed into ~/.claude/settings.json by :AgentsInstallHooks.
# Only agents started by the hub have NVIM_AGENT_SESSION; elsewhere this is a no-op.
#
# Usage: claude-state.sh <event>, with the hook JSON on stdin.
#   idle     SessionStart       status idle
#   prompt   UserPromptSubmit   status running, task = the prompt
#   tool     PreToolUse         status running, activity = what the tool does
#   running  PostToolUse        status running (after a permission prompt)
#   waiting  Notification       status waiting, activity = the request
#   done     Stop               status done
if [ -z "${NVIM_AGENT_SESSION:-}" ]; then
	cat >/dev/null 2>&1
	exit 0
fi

event="${1:-}"
target="=$NVIM_AGENT_SESSION:"

set_opt() {
	tmux -L nvim-agents set-option -t "$target" "$1" "$2" >/dev/null 2>&1
}

# Turns the hook JSON into one short line of text for the office view.
describe() {
	python3 -c '
import json, os, sys

event = sys.argv[1]
try:
    data = json.loads(sys.stdin.read(), strict=False)
except Exception:
    data = {}

def base(path):
    return os.path.basename(path or "")

text = ""
if event == "prompt":
    lines = [l for l in (data.get("prompt") or "").splitlines() if l.strip()]
    text = lines[0] if lines else ""
elif event == "waiting":
    text = data.get("message") or "needs you"
elif event == "tool":
    tool = data.get("tool_name") or ""
    args = data.get("tool_input") or {}
    if tool in ("Edit", "MultiEdit", "Write", "NotebookEdit"):
        text = "Editing " + base(args.get("file_path") or args.get("notebook_path"))
    elif tool == "Read":
        text = "Reading " + base(args.get("file_path"))
    elif tool == "Bash":
        text = "$ " + (args.get("description") or args.get("command") or "")
    elif tool in ("Grep", "Glob"):
        text = "Searching " + (args.get("pattern") or "")
    elif tool == "WebSearch":
        text = "Googling " + (args.get("query") or "")
    elif tool == "WebFetch":
        text = "Browsing " + (args.get("url") or "")
    elif tool in ("Task", "Agent"):
        text = "Delegating: " + (args.get("description") or "")
    elif tool == "TodoWrite":
        text = "Planning"
    else:
        text = tool.split("__")[-1].replace("_", " ")
print(" ".join(text.split())[:80])
' "$1" 2>/dev/null
}

case "$event" in
idle)
	cat >/dev/null 2>&1
	set_opt @agent_status idle
	set_opt @agent_activity ""
	;;
prompt)
	set_opt @agent_status running
	set_opt @agent_task "$(describe prompt)"
	set_opt @agent_activity "Thinking…"
	;;
tool)
	set_opt @agent_status running
	set_opt @agent_activity "$(describe tool)"
	;;
running)
	cat >/dev/null 2>&1
	set_opt @agent_status running
	;;
waiting)
	set_opt @agent_status waiting
	set_opt @agent_activity "$(describe waiting)"
	;;
done)
	cat >/dev/null 2>&1
	set_opt @agent_status done
	set_opt @agent_activity ""
	;;
*)
	cat >/dev/null 2>&1
	;;
esac
exit 0
