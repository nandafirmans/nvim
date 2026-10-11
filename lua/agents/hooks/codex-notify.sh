#!/bin/sh
# Codex `notify` program for the Neovim agent hub (lua/agents). Codex calls
# it with one JSON argument when a turn completes; it marks the tab done and
# records the task and thread id (for `codex resume <id>`). Codex has no
# event for the start of a turn, so "running" still comes from screen
# activity. Set in ~/.codex/config.toml by :AgentsInstallHooks.
# Only agents started by the hub have NVIM_AGENT_SESSION; elsewhere a no-op.
[ -n "${NVIM_AGENT_SESSION:-}" ] || exit 0

python3 -c '
import json, os, subprocess, sys

try:
    data = json.loads(sys.argv[1], strict=False)
except Exception:
    sys.exit(0)
if data.get("type") != "agent-turn-complete":
    sys.exit(0)

target = "=" + os.environ["NVIM_AGENT_SESSION"] + ":"

def set_opt(key, value):
    value = " ".join(str(value or "").split())[:80]
    subprocess.run(["tmux", "-L", "nvim-agents", "set-option", "-t", target, "@agent_" + key, value],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

set_opt("status", "done")
set_opt("activity", "")
messages = data.get("input-messages") or []
if messages and isinstance(messages[-1], str):
    set_opt("task", next((l for l in messages[-1].splitlines() if l.strip()), messages[-1]))
if data.get("thread-id"):
    set_opt("session_id", data["thread-id"])
' "${1:-}" 2>/dev/null
exit 0
