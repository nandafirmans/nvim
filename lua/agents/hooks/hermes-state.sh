#!/bin/sh
# Reports Hermes Agent state to the Neovim agent hub (lua/agents): status,
# task, current activity and the session id, as tmux options on the hub's
# session. Wired into ~/.hermes/config.yaml by :AgentsInstallHooks.
# Only agents started by the hub have NVIM_AGENT_SESSION; elsewhere this is a
# no-op. It prints nothing, so it never blocks or changes a tool call.
#
# Hermes sends {hook_event_name, tool_name, tool_input, session_id, extra} on stdin.
if [ -z "${NVIM_AGENT_SESSION:-}" ]; then
	cat >/dev/null 2>&1
	exit 0
fi

python3 -c '
import json, os, subprocess, sys

try:
    data = json.loads(sys.stdin.read(), strict=False)
except Exception:
    sys.exit(0)

target = "=" + os.environ["NVIM_AGENT_SESSION"] + ":"

def set_opt(key, value):
    value = " ".join(str(value or "").split())[:80]
    subprocess.run(["tmux", "-L", "nvim-agents", "set-option", "-t", target, "@agent_" + key, value],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def describe(tool, args):
    args = args if isinstance(args, dict) else {}
    name = (tool or "").lower()
    path = os.path.basename(str(args.get("path") or args.get("file_path") or ""))
    if name in ("write_file", "patch", "edit_file"):
        return "Editing " + path
    if name in ("read_file",):
        return "Reading " + path
    if name in ("terminal", "execute_code"):
        return "$ " + str(args.get("command") or args.get("code") or "")
    if name in ("search_files", "grep", "find_files"):
        return "Searching " + str(args.get("pattern") or args.get("query") or "")
    if name.startswith("web_search"):
        return "Googling " + str(args.get("query") or "")
    if name.startswith("browser") or name.startswith("web_"):
        return "Browsing " + str(args.get("url") or "")
    if name in ("delegate_task",):
        return "Delegating: " + str(args.get("goal") or args.get("task") or "")
    return name.replace("_", " ")

event = data.get("hook_event_name")
extra = data.get("extra") if isinstance(data.get("extra"), dict) else {}

if event == "on_session_start":
    set_opt("status", "idle")
    set_opt("activity", "")
    if data.get("session_id"):
        set_opt("session_id", data["session_id"])
elif event == "pre_llm_call":
    set_opt("status", "running")
    set_opt("activity", "Thinking…")
    message = extra.get("user_message")
    if isinstance(message, str) and message.strip():
        set_opt("task", next(l for l in message.splitlines() if l.strip()))
elif event == "pre_tool_call":
    set_opt("status", "running")
    set_opt("activity", describe(data.get("tool_name"), data.get("tool_input")))
elif event == "pre_approval_request":
    set_opt("status", "waiting")
    set_opt("activity", "approve " + str(data.get("tool_name") or "tool"))
elif event == "post_approval_response":
    set_opt("status", "running")
elif event == "on_session_end":
    set_opt("status", "done")
    set_opt("activity", "")
' 2>/dev/null
exit 0
