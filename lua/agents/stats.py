#!/usr/bin/env python3
"""Usage analytics for the Neovim agent hub's monitor (lua/agents/monitor.lua).

Reads what each agent CLI already stores on disk, read-only, and prints one
JSON document. Every agent is collected on its own: a missing CLI, missing
data or an unreadable file becomes a status on that agent, never a crash.

status: "ok" | "not_installed" | "no_data" | "error"
windows: "today" (since local midnight), "week" (7 days), "month" (30 days)
"""
import glob
import json
import os
import shutil
import sqlite3
import sys
import time
from datetime import datetime

HOME = os.path.expanduser("~")
NOW = time.time()
MIDNIGHT = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
WINDOWS = {"today": MIDNIGHT, "week": NOW - 7 * 86400, "month": NOW - 30 * 86400}
OLDEST = WINDOWS["month"]


def empty_window():
    return {"sessions": 0, "prompts": 0, "tool_calls": 0, "input": 0, "output": 0,
            "cache": 0, "cost": 0.0, "cost_known": False}


class Collector:
    """Accumulates usage events into windows, a 7-day series and projects."""

    def __init__(self):
        self.windows = {name: empty_window() for name in WINDOWS}
        self.daily = [0] * 7  # tokens per day, oldest first, today last
        self.projects = {}  # name -> tokens (30 days)
        self.models = {}  # name -> tokens (30 days)
        self.sessions = {name: set() for name in WINDOWS}
        self.last_used = 0

    def add(self, ts, session=None, project=None, model=None, input=0, output=0,
            cache=0, cost=None, prompts=0, tool_calls=0):
        if not ts or ts < OLDEST:
            return
        self.last_used = max(self.last_used, ts)
        # Cached input is re-read every turn and dwarfs real work; series,
        # projects and models count fresh input + output only.
        tokens = input + output
        for name, start in WINDOWS.items():
            if ts >= start:
                w = self.windows[name]
                w["input"] += input
                w["output"] += output
                w["cache"] += cache
                w["prompts"] += prompts
                w["tool_calls"] += tool_calls
                if cost is not None:
                    w["cost"] += cost
                    w["cost_known"] = True
                if session:
                    self.sessions[name].add(session)
        day = int((MIDNIGHT - ts) // 86400) + 1 if ts < MIDNIGHT else 0
        if 0 <= day < 7:
            self.daily[6 - day] += tokens
        if project:
            self.projects[project] = self.projects.get(project, 0) + tokens
        if model:
            self.models[model] = self.models.get(model, 0) + tokens

    def result(self):
        for name in WINDOWS:
            self.windows[name]["sessions"] = len(self.sessions[name])
        top = lambda d: sorted(d.items(), key=lambda kv: -kv[1])[:5]
        return {
            "status": "ok" if self.last_used else "no_data",
            "windows": self.windows,
            "daily": self.daily,
            "projects": top(self.projects),
            "models": top(self.models),
            "last_used": self.last_used or None,
        }


def iso(ts):
    """ISO-8601 (with Z) to epoch seconds; None when unparsable."""
    if not isinstance(ts, str):
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def recent_files(pattern):
    for path in glob.glob(pattern, recursive=True):
        try:
            if os.path.getmtime(path) >= OLDEST:
                yield path
        except OSError:
            continue


def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                yield line
    except OSError:
        return


def loads(line):
    try:
        return json.loads(line)
    except ValueError:
        return None


def readonly_db(path):
    return sqlite3.connect("file:%s?mode=ro" % path, uri=True, timeout=2)


# Collectors ------------------------------------------------------------------


def claude(c):
    root = os.path.join(HOME, ".claude", "projects")
    if not os.path.isdir(root):
        return False
    seen = set()  # one assistant message is written as several lines
    for path in recent_files(os.path.join(root, "*", "*.jsonl")):
        session = os.path.splitext(os.path.basename(path))[0]
        for line in read_lines(path):
            is_usage = '"usage"' in line
            is_user = '"type":"user"' in line
            if not (is_usage or is_user):
                continue
            d = loads(line)
            if not isinstance(d, dict):
                continue
            ts = iso(d.get("timestamp"))
            project = os.path.basename(d.get("cwd") or "") or None
            msg = d.get("message") if isinstance(d.get("message"), dict) else {}
            if d.get("type") == "assistant" and isinstance(msg.get("usage"), dict):
                key = (msg.get("id"), d.get("requestId"))
                if key in seen:
                    continue
                seen.add(key)
                u = msg["usage"]
                content = msg.get("content") if isinstance(msg.get("content"), list) else []
                tools = sum(1 for p in content if isinstance(p, dict) and p.get("type") == "tool_use")
                c.add(ts, session, project, msg.get("model"),
                      input=u.get("input_tokens") or 0, output=u.get("output_tokens") or 0,
                      cache=(u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0),
                      tool_calls=tools)
            elif d.get("type") == "user" and isinstance(msg.get("content"), str):
                c.add(ts, session, project, prompts=1)
    return True


def pi_like(c, base):
    """omp and pi (pi-mono) keep one JSONL per session with usage and cost."""
    root = os.path.join(HOME, base, "agent", "sessions")
    if not os.path.isdir(root):
        return False
    for path in recent_files(os.path.join(root, "*", "*.jsonl")):
        session = os.path.splitext(os.path.basename(path))[0]
        project = os.path.basename(os.path.dirname(path)).lstrip("-").split("-")[-1] or None
        for line in read_lines(path):
            if '"cwd"' in line and project:
                d = loads(line)
                if isinstance(d, dict) and isinstance(d.get("cwd"), str):
                    project = os.path.basename(d["cwd"]) or project
            if '"message"' not in line:
                continue
            d = loads(line)
            if not isinstance(d, dict) or not isinstance(d.get("message"), dict):
                continue
            msg = d["message"]
            ts = iso(d.get("timestamp"))
            if msg.get("role") == "assistant" and isinstance(msg.get("usage"), dict):
                u = msg["usage"]
                cost = u.get("cost")
                cost = cost.get("total") if isinstance(cost, dict) else None
                content = msg.get("content") if isinstance(msg.get("content"), list) else []
                tools = sum(1 for p in content if isinstance(p, dict) and p.get("type") == "toolCall")
                c.add(ts, session, project, msg.get("model"),
                      input=u.get("input") or 0, output=u.get("output") or 0,
                      cache=(u.get("cacheRead") or 0) + (u.get("cacheWrite") or 0),
                      cost=cost, tool_calls=tools)
            elif msg.get("role") == "user":
                c.add(ts, session, project, prompts=1)
    return True


def opencode(c):
    db = os.path.join(HOME, ".local", "share", "opencode", "opencode.db")
    if not os.path.isfile(db):
        return False
    con = readonly_db(db)
    try:
        cols = {row[1] for row in con.execute("PRAGMA table_info(session)")}
        created = "time_created" if "time_created" in cols else "time_updated"
        rows = con.execute(
            "SELECT id, directory, %s, cost, tokens_input, tokens_output, "
            "tokens_cache_read + tokens_cache_write FROM session WHERE parent_id IS NULL" % created)
        for sid, directory, ts, cost, tin, tout, tcache in rows:
            ts = (ts or 0) / 1000 if (ts or 0) > 1e12 else ts
            c.add(ts, sid, os.path.basename(directory or "") or None,
                  input=tin or 0, output=tout or 0, cache=tcache or 0,
                  cost=cost if cost else None)
        # Prompts: user messages per session.
        for (ts,) in con.execute(
                "SELECT m.time_created FROM message m JOIN session s ON s.id = m.session_id "
                "WHERE s.parent_id IS NULL AND m.data LIKE '%\"role\":\"user\"%'"):
            c.add((ts or 0) / 1000, prompts=1)
    finally:
        con.close()
    return True


def codex(c):
    root = os.path.join(HOME, ".codex", "sessions")
    if not os.path.isdir(root):
        return False
    for path in recent_files(os.path.join(root, "**", "*.jsonl")):
        session, project, last, last_ts, prompts, tools = path, None, None, None, 0, 0
        for line in read_lines(path):
            d = loads(line)
            if not isinstance(d, dict):
                continue
            payload = d.get("payload") if isinstance(d.get("payload"), dict) else {}
            kind = payload.get("type")
            if d.get("type") == "session_meta":
                session = payload.get("id") or session
                project = os.path.basename(payload.get("cwd") or "") or None
            elif kind == "token_count" and isinstance(payload.get("info"), dict):
                last = payload["info"].get("total_token_usage") or last
                last_ts = iso(d.get("timestamp")) or last_ts
            elif kind == "user_message":
                prompts += 1
            elif d.get("type") == "response_item" and kind in ("function_call", "custom_tool_call", "local_shell_call"):
                tools += 1
        ts = last_ts or os.path.getmtime(path)
        u = last or {}
        cached = u.get("cached_input_tokens") or 0
        c.add(ts, session, project,
              input=max(0, (u.get("input_tokens") or 0) - cached), output=u.get("output_tokens") or 0,
              cache=cached, prompts=prompts, tool_calls=tools)
    return True


def hermes(c):
    db = os.path.join(HOME, ".hermes", "state.db")
    if not os.path.isfile(db):
        return False
    con = readonly_db(db)
    try:
        rows = con.execute(
            "SELECT id, cwd, model, started_at, input_tokens, output_tokens, "
            "cache_read_tokens + cache_write_tokens, COALESCE(actual_cost_usd, estimated_cost_usd), "
            "message_count, tool_call_count, source FROM sessions WHERE parent_session_id IS NULL AND started_at >= ?",
            (OLDEST,))
        for sid, cwd, model, ts, tin, tout, tcache, cost, msgs, tools, source in rows:
            project = os.path.basename(cwd or "") or (source or None)
            # Hermes stores 0 when it has no pricing for a model: unknown, not free.
            c.add(ts, sid, project, model, input=tin or 0, output=tout or 0, cache=tcache or 0,
                  cost=cost if cost else None, prompts=1, tool_calls=tools or 0)
    finally:
        con.close()
    return True


COLLECTORS = [
    ("claude", "claude", claude),
    ("omp", "omp", lambda c: pi_like(c, ".omp")),
    ("pi", "pi", lambda c: pi_like(c, ".pi")),
    ("opencode", "opencode", opencode),
    ("codex", "codex", codex),
    ("hermes", "hermes", hermes),
]


def main():
    out = {"generated_at": NOW, "agents": []}
    for name, binary, collect in COLLECTORS:
        entry = {"name": name, "installed": shutil.which(binary) is not None}
        c = Collector()
        try:
            found = collect(c)
            if found:
                entry.update(c.result())
            else:
                entry["status"] = "no_data" if entry["installed"] else "not_installed"
        except Exception as e:  # one broken source must not hide the others
            entry["status"] = "error"
            entry["message"] = "%s: %s" % (type(e).__name__, e)
        out["agents"].append(entry)
    json.dump(out, sys.stdout)


if __name__ == "__main__":
    main()
