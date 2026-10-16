// The agent's tools. Each one: { name, description, parameters (JSON
// schema), readOnly, run(args, ctx) -> { text, isError? } }. ctx carries the
// working directory, the abort signal, the files read this session (edits
// need a read first, so the model never edits blind) and the todo list.
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const MAX_OUTPUT = 30000;
const MAX_LINE = 2000;

function resolve(ctx, p) {
  if (!p) throw new Error("path is required");
  const expanded = p.startsWith("~/") ? path.join(process.env.HOME, p.slice(2)) : p;
  return path.resolve(ctx.cwd, expanded);
}

function rel(ctx, p) {
  const r = path.relative(ctx.cwd, p);
  return r && !r.startsWith("..") ? r : p;
}

// Keeps the head and the tail of long output, where the useful parts usually are.
export function clip(text, max = MAX_OUTPUT) {
  if (text.length <= max) return text;
  const half = Math.floor(max / 2);
  return `${text.slice(0, half)}\n\n[… ${text.length - max} characters cut …]\n\n${text.slice(-half)}`;
}

// Runs a program; resolves { code, stdout, stderr }. Killed (whole process
// group) on abort or timeout.
export function run(cmd, args, { cwd, signal, timeout = 120000, input } = {}) {
  return new Promise((resolvePromise) => {
    const child = spawn(cmd, args, { cwd, detached: true, stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let killedBy = "";
    const kill = (why) => {
      killedBy = why;
      try {
        process.kill(-child.pid, "SIGKILL");
      } catch {}
    };
    const timer = setTimeout(() => kill("timeout"), timeout);
    const onAbort = () => kill("interrupted");
    signal?.addEventListener("abort", onAbort);
    child.stdout.on("data", (d) => {
      stdout += d;
      if (stdout.length > 5 * MAX_OUTPUT) stdout = stdout.slice(-5 * MAX_OUTPUT);
    });
    child.stderr.on("data", (d) => {
      stderr += d;
      if (stderr.length > 5 * MAX_OUTPUT) stderr = stderr.slice(-5 * MAX_OUTPUT);
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      resolvePromise({ code: 127, stdout, stderr: err.message, killedBy });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      signal?.removeEventListener("abort", onAbort);
      resolvePromise({ code: code ?? 1, stdout, stderr, killedBy });
    });
    if (input) child.stdin.write(input);
    child.stdin.end();
  });
}

// read -------------------------------------------------------------------------

const read = {
  name: "read",
  readOnly: true,
  description:
    "Read a file. Returns lines numbered like `cat -n` (number, tab, text). Reads up to 2000 lines from `offset` (1-based); " +
    "use offset/limit for large files. Read a file before editing it. Can also list a directory.",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string", description: "File path, absolute or relative to the working directory" },
      offset: { type: "integer", description: "First line to read (1-based)" },
      limit: { type: "integer", description: "Number of lines (default 2000)" },
    },
    required: ["path"],
  },
  async run(args, ctx) {
    const file = resolve(ctx, args.path);
    const stat = fs.statSync(file);
    if (stat.isDirectory()) {
      const entries = fs.readdirSync(file, { withFileTypes: true }).map((e) => (e.isDirectory() ? e.name + "/" : e.name));
      return { text: entries.sort().join("\n") || "(empty directory)" };
    }
    const buffer = fs.readFileSync(file);
    if (buffer.subarray(0, 8000).includes(0)) return { text: `${rel(ctx, file)} is a binary file (${stat.size} bytes)` };
    ctx.readFiles.set(file, stat.mtimeMs);
    const lines = buffer.toString("utf8").split("\n");
    if (lines.length > 1 && lines[lines.length - 1] === "") lines.pop();
    const start = Math.max(1, args.offset ?? 1);
    const limit = Math.max(1, args.limit ?? 2000);
    const slice = lines.slice(start - 1, start - 1 + limit);
    const body = slice
      .map((line, i) => `${String(start + i).padStart(6)}\t${line.length > MAX_LINE ? line.slice(0, MAX_LINE) + "…" : line}`)
      .join("\n");
    const more = start - 1 + slice.length < lines.length ? `\n\n(${lines.length} lines in total; continue with offset ${start + slice.length})` : "";
    return { text: (body || "(empty file)") + more };
  },
};

// write / edit -------------------------------------------------------------------

function mustHaveRead(ctx, file) {
  if (!fs.existsSync(file)) return;
  const seen = ctx.readFiles.get(file);
  if (seen === undefined) throw new Error(`Read ${rel(ctx, file)} before changing it.`);
  if (fs.statSync(file).mtimeMs !== seen) throw new Error(`${rel(ctx, file)} changed since you read it; read it again.`);
}

// A few lines around a change, with +/- markers, for the transcript.
function preview(before, after) {
  const a = before.split("\n");
  const b = after.split("\n");
  let start = 0;
  while (start < a.length && start < b.length && a[start] === b[start]) start++;
  let endA = a.length - 1;
  let endB = b.length - 1;
  while (endA > start && endB > start && a[endA] === b[endB]) {
    endA--;
    endB--;
  }
  const out = [];
  for (let i = Math.max(0, start - 2); i < start; i++) out.push(`  ${i + 1} ${a[i]}`);
  for (let i = start; i <= endA && i - start < 40; i++) out.push(`- ${i + 1} ${a[i]}`);
  for (let i = start; i <= endB && i - start < 40; i++) out.push(`+ ${i + 1} ${b[i]}`);
  for (let i = endB + 1; i < Math.min(b.length, endB + 3); i++) out.push(`  ${i + 1} ${b[i]}`);
  return out.join("\n");
}

const write = {
  name: "write",
  description:
    "Create a file or replace its whole content. For changes to an existing file prefer `edit`; an existing file must be read first.",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string" },
      content: { type: "string", description: "The complete new content" },
    },
    required: ["path", "content"],
  },
  summary: (args) => args.path,
  async run(args, ctx) {
    const file = resolve(ctx, args.path);
    mustHaveRead(ctx, file);
    const existed = fs.existsSync(file);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, args.content ?? "");
    ctx.readFiles.set(file, fs.statSync(file).mtimeMs);
    const lines = (args.content ?? "").split("\n").length;
    return { text: `${existed ? "Rewrote" : "Created"} ${rel(ctx, file)} (${lines} lines)` };
  },
};

// Matching that forgives trailing whitespace and indentation differences, so
// a slightly-off old_string still lands, but only when it is unambiguous.
function looseFind(content, needle) {
  const norm = (s) => s.split("\n").map((l) => l.trim()).join("\n");
  const lines = content.split("\n");
  const want = norm(needle).split("\n");
  const hits = [];
  for (let i = 0; i + want.length <= lines.length; i++) {
    let ok = true;
    for (let j = 0; j < want.length; j++) {
      if (lines[i + j].trim() !== want[j]) {
        ok = false;
        break;
      }
    }
    if (ok) hits.push(i);
  }
  if (hits.length !== 1) return null;
  const startOffset = lines.slice(0, hits[0]).join("\n").length + (hits[0] > 0 ? 1 : 0);
  const original = lines.slice(hits[0], hits[0] + want.length).join("\n");
  return { start: startOffset, original };
}

const edit = {
  name: "edit",
  description:
    "Replace exact text in a file. `old_string` must match the file exactly (copy it from `read` output without the line-number prefix) " +
    "and be unique unless `replace_all` is true; include enough surrounding lines to make it unique. Read the file first.",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string" },
      old_string: { type: "string", description: "Text to replace" },
      new_string: { type: "string", description: "Replacement text" },
      replace_all: { type: "boolean", description: "Replace every occurrence" },
    },
    required: ["path", "old_string", "new_string"],
  },
  summary: (args) => args.path,
  async run(args, ctx) {
    const file = resolve(ctx, args.path);
    if (!fs.existsSync(file)) throw new Error(`${rel(ctx, file)} does not exist; use write to create it.`);
    mustHaveRead(ctx, file);
    const before = fs.readFileSync(file, "utf8");
    const oldText = args.old_string ?? "";
    if (oldText === args.new_string) throw new Error("old_string and new_string are the same.");
    let after;
    if (oldText === "") throw new Error("old_string is empty; use write for a new file.");
    const count = before.split(oldText).length - 1;
    if (count === 0) {
      const loose = looseFind(before, oldText);
      if (!loose) throw new Error("old_string not found in the file. Read the file again and copy the exact text.");
      after = before.slice(0, loose.start) + args.new_string + before.slice(loose.start + loose.original.length);
    } else if (count > 1 && !args.replace_all) {
      throw new Error(`old_string appears ${count} times; add surrounding lines to make it unique, or set replace_all.`);
    } else {
      after = args.replace_all ? before.split(oldText).join(args.new_string) : before.replace(oldText, () => args.new_string);
    }
    fs.writeFileSync(file, after);
    ctx.readFiles.set(file, fs.statSync(file).mtimeMs);
    return { text: `Edited ${rel(ctx, file)}\n${preview(before, after)}` };
  },
};

// bash ---------------------------------------------------------------------------

// Commands that only look at things run without asking.
const SAFE = /^(ls|pwd|cat|head|tail|wc|file|stat|which|echo|rg|grep|tree|du|df|date|uname|node -v|git (status|diff|log|show|branch|remote|rev-parse|ls-files|blame))\b/;

export function isSafeCommand(command) {
  const c = command.trim();
  return SAFE.test(c) && !/[;&|`<>]|\$\(/.test(c.replace(/\|\s*(head|tail|wc|sort|uniq)\b[^|;&]*/g, ""));
}

const bash = {
  name: "bash",
  description:
    "Run a shell command (bash) in the working directory and return its output. Each call starts in the working directory; " +
    "chain with && when steps depend on each other. Use for git, builds, tests, package managers. Prefer `read`, `grep` and `glob` " +
    "over cat/grep/find. Default timeout 120 s, max 600 s; do not start servers that never exit.",
  parameters: {
    type: "object",
    properties: {
      command: { type: "string" },
      description: { type: "string", description: "What it does, in a few words" },
      timeout: { type: "integer", description: "Seconds (max 600)" },
    },
    required: ["command"],
  },
  summary: (args) => `$ ${args.command}`,
  safe: (args) => isSafeCommand(args.command ?? ""),
  async run(args, ctx) {
    const timeout = Math.min(600, Math.max(1, args.timeout ?? 120)) * 1000;
    const result = await run("/bin/bash", ["-c", args.command], { cwd: ctx.cwd, signal: ctx.signal, timeout });
    let text = [result.stdout, result.stderr].filter((s) => s.trim()).join(result.stdout && result.stderr ? "\n" : "");
    text = clip(text.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, ""));
    if (result.killedBy === "timeout") text += `\n[killed after ${timeout / 1000} s]`;
    if (result.killedBy === "interrupted") text += "\n[interrupted]";
    if (result.code !== 0) text += `\n[exit code ${result.code}]`;
    return { text: text.trim() || "(no output)", isError: result.code !== 0 };
  },
};

// grep / glob ---------------------------------------------------------------------

const grep = {
  name: "grep",
  readOnly: true,
  description:
    "Search file contents with ripgrep (regex). Respects .gitignore. output_mode: files_with_matches (default), content (matching lines with numbers), count.",
  parameters: {
    type: "object",
    properties: {
      pattern: { type: "string", description: "Regular expression" },
      path: { type: "string", description: "File or folder (default: working directory)" },
      glob: { type: "string", description: 'Only files matching, e.g. "*.ts" or "src/**/*.lua"' },
      output_mode: { type: "string", enum: ["files_with_matches", "content", "count"] },
      ignore_case: { type: "boolean" },
      context: { type: "integer", description: "Lines of context around matches (content mode)" },
      head_limit: { type: "integer", description: "Max lines of output (default 250)" },
    },
    required: ["pattern"],
  },
  async run(args, ctx) {
    const rgArgs = ["--color=never", "--no-heading"];
    const mode = args.output_mode ?? "files_with_matches";
    if (mode === "files_with_matches") rgArgs.push("-l");
    else if (mode === "count") rgArgs.push("-c");
    else rgArgs.push("-n");
    if (args.ignore_case) rgArgs.push("-i");
    if (args.context && mode === "content") rgArgs.push("-C", String(args.context));
    if (args.glob) rgArgs.push("-g", args.glob);
    rgArgs.push("-e", args.pattern, "--", args.path ? resolve(ctx, args.path) : ".");
    const result = await run("rg", rgArgs, { cwd: ctx.cwd, signal: ctx.signal, timeout: 60000 });
    if (result.code === 127) throw new Error("ripgrep (rg) is not installed");
    if (result.code === 1) return { text: "No matches." };
    if (result.code !== 0) throw new Error(result.stderr.trim());
    const lines = result.stdout.split("\n").filter(Boolean);
    const limit = args.head_limit ?? 250;
    const shown = lines.slice(0, limit).join("\n");
    return { text: clip(shown) + (lines.length > limit ? `\n[${lines.length - limit} more lines]` : "") };
  },
};

const glob = {
  name: "glob",
  readOnly: true,
  description: 'Find files by name pattern, e.g. "**/*.tsx" or "src/**/test_*.py". Respects .gitignore. Newest first.',
  parameters: {
    type: "object",
    properties: {
      pattern: { type: "string" },
      path: { type: "string", description: "Folder to search (default: working directory)" },
    },
    required: ["pattern"],
  },
  async run(args, ctx) {
    const base = args.path ? resolve(ctx, args.path) : ctx.cwd;
    const result = await run("rg", ["--files", "--hidden", "-g", "!.git", "-g", args.pattern], { cwd: base, signal: ctx.signal, timeout: 60000 });
    if (result.code === 127) throw new Error("ripgrep (rg) is not installed");
    const files = result.stdout.split("\n").filter(Boolean);
    if (!files.length) return { text: "No files found." };
    const withTime = files.map((f) => {
      let t = 0;
      try {
        t = fs.statSync(path.join(base, f)).mtimeMs;
      } catch {}
      return [f, t];
    });
    withTime.sort((a, b) => b[1] - a[1]);
    const shown = withTime.slice(0, 200).map(([f]) => (base === ctx.cwd ? f : path.join(rel(ctx, base), f)));
    return { text: shown.join("\n") + (files.length > 200 ? `\n[${files.length - 200} more]` : "") };
  },
};

// todo ----------------------------------------------------------------------------

const todo = {
  name: "todo_write",
  readOnly: true,
  description:
    "Keep a task list for work with 3+ steps: send the whole list each time. Exactly one item in_progress while working; " +
    "mark items completed as soon as they are done.",
  parameters: {
    type: "object",
    properties: {
      todos: {
        type: "array",
        items: {
          type: "object",
          properties: {
            content: { type: "string" },
            status: { type: "string", enum: ["pending", "in_progress", "completed"] },
          },
          required: ["content", "status"],
        },
      },
    },
    required: ["todos"],
  },
  async run(args, ctx) {
    ctx.todos = Array.isArray(args.todos) ? args.todos : [];
    ctx.ui?.todos?.(ctx.todos);
    const open = ctx.todos.filter((t) => t.status !== "completed").length;
    return { text: `Todo list updated (${open} open).` };
  },
};

// web_fetch ------------------------------------------------------------------------

const webFetch = {
  name: "web_fetch",
  readOnly: true,
  description: "Fetch a URL (docs, issues, API references) and return its text, with HTML reduced to readable text.",
  parameters: {
    type: "object",
    properties: { url: { type: "string" } },
    required: ["url"],
  },
  async run(args, ctx) {
    const response = await fetch(args.url, { signal: ctx.signal, headers: { "user-agent": "wowo" }, redirect: "follow" });
    let body = await response.text();
    if ((response.headers.get("content-type") ?? "").includes("html")) {
      body = body
        .replace(/<(script|style|noscript|svg)[\s\S]*?<\/\1>/gi, "")
        .replace(/<\/(p|div|h[1-6]|li|tr|pre|br)>/gi, "\n")
        .replace(/<[^>]+>/g, "")
        .replace(/&nbsp;/g, " ")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, '"')
        .replace(/\n\s*\n\s*\n+/g, "\n\n");
    }
    return { text: `HTTP ${response.status}\n\n${clip(body.trim(), 20000)}`, isError: !response.ok };
  },
};

// task (subagent) ------------------------------------------------------------------

const task = {
  name: "task",
  readOnly: true,
  description:
    "Hand a self-contained research question to a subagent with read-only tools (read, grep, glob, safe bash). " +
    "Use it to explore a large codebase without filling your own context; give it a complete brief and say what to report back.",
  parameters: {
    type: "object",
    properties: {
      description: { type: "string", description: "A few words, shown to the user" },
      prompt: { type: "string", description: "The full brief" },
    },
    required: ["prompt"],
  },
  summary: (args) => args.description ?? String(args.prompt ?? "").slice(0, 60),
  async run(args, ctx) {
    if (!ctx.subagent) throw new Error("subagents are not available here");
    return { text: await ctx.subagent(args.prompt) };
  },
};

// skill ------------------------------------------------------------------------------

const skill = {
  name: "skill",
  readOnly: true,
  description: "Load a skill's instructions by name (see the skills list in the system prompt) before doing the task it covers.",
  parameters: {
    type: "object",
    properties: { name: { type: "string" } },
    required: ["name"],
  },
  async run(args, ctx) {
    const found = ctx.skills?.find((s) => s.name === args.name);
    if (!found) throw new Error(`No skill named ${args.name}`);
    return { text: fs.readFileSync(found.file, "utf8") };
  },
};

export const TOOLS = [read, write, edit, bash, grep, glob, todo, webFetch, task, skill];

export const READ_ONLY = TOOLS.filter((t) => t.readOnly && t.name !== "task" && t.name !== "todo_write");
