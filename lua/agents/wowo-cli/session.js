// Sessions: one JSONL file per conversation in
// ~/.wowo/agent/sessions/-<cwd relative to home, "/" as "-">/<time>_<id>.jsonl,
// the layout omp and pi use, so the hub's handoff and usage monitor read it
// the same way. Lines: a "session" header, then "message" and "compaction".
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { AGENT_DIR } from "./config.js";

export function sessionDir(cwd) {
  const home = os.homedir();
  const relative = cwd.startsWith(home) ? cwd.slice(home.length) : cwd;
  return path.join(AGENT_DIR, "sessions", relative.replace(/\//g, "-"));
}

export class Session {
  constructor(file, id, cwd) {
    this.file = file;
    this.id = id;
    this.cwd = cwd;
  }

  static create(cwd) {
    const id = crypto.randomUUID();
    const dir = sessionDir(cwd);
    fs.mkdirSync(dir, { recursive: true });
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    const session = new Session(path.join(dir, `${stamp}_${id}.jsonl`), id, cwd);
    session.append({ type: "session", id, cwd, timestamp: new Date().toISOString() });
    return session;
  }

  // Sessions in this folder, newest first: [{ file, id, mtime, title }].
  static list(cwd) {
    const dir = sessionDir(cwd);
    let names = [];
    try {
      names = fs.readdirSync(dir).filter((n) => n.endsWith(".jsonl"));
    } catch {
      return [];
    }
    return names
      .map((name) => {
        const file = path.join(dir, name);
        const id = name.replace(/\.jsonl$/, "").split("_").pop();
        let title = "";
        for (const line of fs.readFileSync(file, "utf8").split("\n")) {
          if (!line.includes('"user"')) continue;
          try {
            const d = JSON.parse(line);
            if (d.message?.role === "user" && typeof d.message.content === "string") {
              title = d.message.content.split("\n")[0].slice(0, 70);
              break;
            }
          } catch {}
        }
        return { file, id, mtime: fs.statSync(file).mtimeMs, title };
      })
      .sort((a, b) => b.mtime - a.mtime);
  }

  // An id (or a prefix of one), a path, or "latest".
  static open(cwd, which) {
    let found;
    if (which && fs.existsSync(which)) {
      found = { file: path.resolve(which), id: path.basename(which, ".jsonl").split("_").pop() };
    } else {
      const all = Session.list(cwd);
      found = which && which !== "latest" ? all.find((s) => s.id.startsWith(which)) : all[0];
    }
    if (!found) return null;
    const session = new Session(found.file, found.id, cwd);
    return { session, messages: session.load() };
  }

  // The conversation to continue: the latest summary, then what came after it.
  load() {
    let messages = [];
    for (const line of fs.readFileSync(this.file, "utf8").split("\n")) {
      if (!line.trim()) continue;
      let d;
      try {
        d = JSON.parse(line);
      } catch {
        continue;
      }
      if (d.type === "message" && d.message) messages.push(d.message);
      if (d.type === "compaction") messages = [{ role: "user", content: d.summary }];
    }
    return messages;
  }

  append(entry) {
    fs.appendFileSync(this.file, JSON.stringify(entry) + "\n");
  }

  message(message) {
    this.append({ type: "message", timestamp: new Date().toISOString(), message });
  }

  compaction(summary) {
    this.append({ type: "compaction", timestamp: new Date().toISOString(), summary });
  }
}
