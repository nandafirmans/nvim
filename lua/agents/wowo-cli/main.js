#!/usr/bin/env node
// wowo: a bring-your-own-key coding agent for the terminal and the
// Neovim agent hub. Zero dependencies; Node 20+.
//
//   wowo [prompt]            interactive, optionally starting with a prompt
//   wowo -p "prompt"         print mode: run to the end, print the answer, exit
//   wowo -c | --continue     continue the latest session in this folder
//   wowo -r [id]             resume a session (latest without an id)
//   wowo --model <ref>       provider/model (or a unique part of it)
//   wowo --yolo | --edits    approve everything / file edits without asking
//   wowo --models            list the configured models
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { Agent } from "./agent.js";
import { HOME, findModel, listModels, loadConfig, resolveKey } from "./config.js";
import * as hub from "./hub.js";
import { findSkills } from "./prompt.js";
import { Session } from "./session.js";
import { TOOLS } from "./tools.js";
import { Editor, MODES, MODE_ORDER, P, UI, normalizeMode, accent, c, card, faint, gradient, grey, red, text, violet } from "./ui.js";

const VERSION = "0.1.0";

function parseArgs(argv) {
  const opts = { prompt: [], print: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    if (a === "-p" || a === "--print") opts.print = true;
    else if (a === "-c" || a === "--continue") opts.resume = "latest";
    else if (a === "-r" || a === "--resume") opts.resume = argv[i + 1] && !argv[i + 1].startsWith("-") ? next() : "latest";
    else if (a === "--model" || a === "-m") opts.model = next();
    else if (a.startsWith("--model=")) opts.model = a.slice(8);
    else if (a === "--yolo" || a === "--auto") opts.mode = "yolo";
    else if (a === "--edits") opts.mode = "edits";
    else if (a === "--cwd") opts.cwd = next();
    else if (a === "--models") opts.listModels = true;
    else if (a === "--version" || a === "-v") opts.version = true;
    else if (a === "--help" || a === "-h") opts.help = true;
    else opts.prompt.push(a);
  }
  opts.prompt = opts.prompt.join(" ").trim();
  return opts;
}

const HELP = `wowo ${VERSION} — your keys, your agent

Usage: wowo [options] [prompt]

  -p, --print          run the prompt to the end and print the answer (approves everything)
  -c, --continue       continue the latest session in this folder
  -r, --resume [id]    resume a session by id (prefix), or the latest
  -m, --model <ref>    provider/model, or a unique part of it
      --auto           approve every tool call (alias --yolo)
      --edits          approve file edits; still ask for commands
      --cwd <dir>      work in another folder
      --models         list configured models
Config: ${path.join(HOME, "config.json")} (written by the Neovim hub from wowo.providers)`;

const COMMANDS = {
  help: "Show commands",
  model: "Switch model: /model <ref or number>",
  models: "List models",
  compact: "Summarize the conversation to free context: /compact [focus]",
  clear: "Start a new conversation",
  resume: "List sessions here, or /resume <id>",
  cost: "Tokens used this session",
  mode: "Approvals: /mode ask | auto-edit | auto (or ⇧tab)",
  skills: "List skills",
  todos: "Show the todo list",
  exit: "Quit",
};

// Files of the project for @ suggestions (git-aware, via ripgrep), cached.
let fileCache = null;
function projectFiles(cwd) {
  if (fileCache) return fileCache;
  try {
    fileCache = execFileSync("rg", ["--files", "--hidden", "-g", "!.git"], { cwd, encoding: "utf8", maxBuffer: 32 * 1024 * 1024, timeout: 5000 })
      .split("\n")
      .filter(Boolean)
      .slice(0, 20000)
      .sort();
  } catch {
    fileCache = [];
  }
  setTimeout(() => (fileCache = null), 30000).unref();
  return fileCache;
}

// Input piped or redirected in (not a terminal, not an idle inherited fd).
function stdinIsPiped() {
  try {
    const stat = fs.fstatSync(0);
    return stat.isFIFO() || stat.isFile();
  } catch {
    return false;
  }
}

function branchOf(cwd) {
  try {
    return execFileSync("git", ["-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return "";
  }
}

// Plain output for print mode: the answer on stdout, progress on stderr.
class PrintUI {
  constructor() {
    this.answer = "";
  }
  startReply() {
    this.answer = "";
  }
  text(t) {
    this.answer += t;
  }
  thinking() {}
  endReply() {}
  toolStart(name, args, summary) {
    process.stderr.write(grey(`● ${name} ${String(summary ?? args?.path ?? args?.pattern ?? "").split("\n")[0].slice(0, 100)}\n`));
  }
  toolEnd(name, text, isError) {
    if (isError) process.stderr.write(red(`  ⎿ ${String(text).split("\n")[0].slice(0, 200)}\n`));
  }
  subTool() {}
  todos() {}
  usage() {}
  notice(t) {
    process.stderr.write(grey(`› ${t}\n`));
  }
  error(t) {
    process.stderr.write(red(`✗ ${t}\n`));
  }
  approve() {
    return Promise.resolve({ choice: "yes" });
  }
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.version) return console.log(VERSION);
  if (opts.help) return console.log(HELP);

  const config = loadConfig();
  if (opts.listModels) {
    for (const m of listModels(config)) console.log(`${m.ref === config.model ? "*" : " "} ${m.ref}  (${Math.round(m.context / 1000)}k)`);
    return;
  }
  const cwd = path.resolve(opts.cwd ?? process.cwd());
  let model = findModel(config, opts.model);
  if (!model) {
    console.error(
      opts.model
        ? `wowo: no model matches "${opts.model}" (see wowo --models)`
        : `wowo: no models configured. Add providers to ${path.join(HOME, "config.json")} (the Neovim hub writes it from wowo.providers).`,
    );
    process.exit(2);
  }
  const providerOf = (m) => config.providers[m.provider];
  if (providerOf(model).api_key && !resolveKey(providerOf(model).api_key)) {
    console.error(`wowo: the key for ${model.provider} was not found (${providerOf(model).api_key})`);
    process.exit(2);
  }

  let session;
  let messages = [];
  let resumed = false;
  if (opts.resume) {
    const found = Session.open(cwd, opts.resume);
    if (found) {
      ({ session, messages } = found);
      resumed = true;
    } else if (opts.resume !== "latest") {
      console.error(`wowo: no session ${opts.resume} in ${cwd}`);
      process.exit(2);
    }
  }
  session ??= Session.create(cwd);
  hub.report("session_id", session.id);

  const skills = findSkills(cwd);
  const print = opts.print || !process.stdin.isTTY || !process.stdout.isTTY;
  const ui = print ? new PrintUI() : new UI();
  const mode = opts.mode ?? (print ? "yolo" : normalizeMode(config.permissions) ?? "ask");
  const agent = new Agent({ config: { ...config, permissions: mode }, model, provider: providerOf(model), cwd, session, messages, ui, skills });

  // Print mode ---------------------------------------------------------------------
  if (print) {
    let prompt = opts.prompt;
    if (stdinIsPiped()) {
      let input = "";
      for await (const chunk of process.stdin) input += chunk;
      prompt = [prompt, input.trim()].filter(Boolean).join("\n\n");
    }
    if (!prompt) {
      console.error("wowo: -p needs a prompt");
      process.exit(2);
    }
    process.on("SIGINT", () => agent.interrupt());
    const result = await agent.prompt(prompt);
    process.stdout.write(ui.answer.trim() + "\n");
    process.exit(result === "done" ? 0 : 1);
  }

  // Interactive --------------------------------------------------------------------
  const editor = new Editor({
    complete: (before) => {
      const slashWord = before.match(/^\s*(\/[\w:.-]*)$/);
      if (slashWord) {
        const token = slashWord[1];
        const q = token.slice(1).toLowerCase();
        const all = [
          ...Object.entries(COMMANDS).map(([name, desc]) => ({ value: "/" + name, desc, kind: "command" })),
          ...skills.map((sk) => ({ value: "/" + sk.name, desc: sk.description, kind: "skill" })),
        ];
        const starts = all.filter((it) => it.value.slice(1).toLowerCase().startsWith(q));
        const contains = all.filter((it) => !starts.includes(it) && it.value.toLowerCase().includes(q));
        return { token, items: [...starts, ...contains] };
      }
      const at = before.match(/(?:^|\s)(@[^\s]*)$/);
      if (at) {
        const token = at[1];
        const q = token.slice(1).toLowerCase();
        const files = projectFiles(cwd);
        const base = (f) => f.split("/").pop().toLowerCase();
        const starts = files.filter((f) => base(f).startsWith(q));
        const contains = files.filter((f) => !base(f).startsWith(q) && f.toLowerCase().includes(q));
        return { token, items: [...starts, ...contains].slice(0, 200).map((f) => ({ value: "@" + f, kind: "file" })) };
      }
      return null;
    },
  });
  ui.editor = editor;
  // ⇧tab cycles ask → auto-edit → auto; the line above the input shows it.
  editor.header = () => ui.inputHeader(agent.mode);
  editor.onShiftTab = () => {
    agent.mode = MODE_ORDER[(MODE_ORDER.indexOf(agent.mode) + 1) % MODE_ORDER.length];
  };
  const typeahead = [];

  process.stdin.setRawMode(true);
  process.stdin.setEncoding("utf8");
  process.stdout.write("\x1b[?2004h"); // bracketed paste
  const restore = () => {
    process.stdout.write("\x1b[?2004l");
    try {
      process.stdin.setRawMode(false);
    } catch {}
  };
  process.on("exit", restore);

  process.stdin.on("data", (data) => {
    if (ui.onKey) {
      // Escape sequences go whole; typed text one character at a time.
      if (data.startsWith("\x1b")) return ui.onKey(data);
      for (const ch of data) {
        if (!ui.onKey) break;
        ui.onKey(ch);
      }
      return;
    }
    if (editor.active) {
      const rest = editor.feed(data);
      if (rest) typeahead.push(rest);
      return;
    }
    if (data === "\x1b" || data === "\x03") {
      if (agent.busy) agent.interrupt();
      return;
    }
    // Typed (or pasted by the hub) while working: kept for the next prompt.
    typeahead.push(data);
  });

  ui.banner({ model, cwd, branch: branchOf(cwd), session: session.id, mode, resumed, skills, tools: TOOLS.map((t) => t.name), version: VERSION });
  if (resumed) {
    const last = [...messages].reverse().find((m) => m.role === "user" && typeof m.content === "string");
    ui.info(`  ${violet("↺")} ${grey(`${messages.length} messages`)}${last ? ` ${faint("· last request:")} ${text(last.content.split("\n")[0].slice(0, 70))}` : ""}\n`);
  }
  hub.status("idle", "");

  const run = async (text) => {
    await agent.prompt(text);
    ui.footer(agent.model, agent.totals);
  };

  const slash = async (line) => {
    const [name, ...rest] = line.slice(1).split(/\s+/);
    const arg = rest.join(" ").trim();
    switch (name) {
      case "help": {
        const lines = Object.entries(COMMANDS).map(([k, v]) => `${accent("/" + k.padEnd(9))} ${grey(v)}`);
        lines.push("", `${accent("/<skill>".padEnd(10))}${grey("run a skill with an optional request")}`);
        lines.push("", grey("⏎ send · \\⏎ or Ctrl-J new line · Esc interrupt · Tab complete · ↑↓ history"));
        return ui.info(card(gradient("commands", [P.pink, P.violet]), lines, P.faint));
      }
      case "models":
      case "model": {
        const all = listModels(config);
        let wanted = /^\d+$/.test(arg) ? all[Number(arg) - 1]?.ref : arg;
        if (!wanted) {
          wanted = await ui.pick({
            title: "model",
            items: all.map((m) => ({ label: m.ref, detail: `${Math.round(m.context / 1000)}k`, value: m.ref })),
            current: agent.model.ref,
          });
          if (!wanted) return;
        }
        const m = findModel(config, wanted);
        if (!m) return ui.error(`No model matches ${arg}`);
        agent.model = m;
        agent.provider = providerOf(m);
        model = m;
        return ui.notice(`Model: ${m.ref}`);
      }
      case "compact": {
        agent.controller = new AbortController();
        try {
          await agent.compact(agent.controller.signal, arg);
        } catch (err) {
          ui.error(err.message);
        } finally {
          agent.controller = null;
        }
        return;
      }
      case "clear":
        agent.session = Session.create(cwd);
        agent.messages = [];
        agent.lastContext = 0;
        agent.ctx.readFiles.clear();
        hub.report("session_id", agent.session.id);
        return ui.notice(`New conversation (${agent.session.id.slice(0, 8)})`);
      case "resume": {
        let id = arg;
        if (!id) {
          const list = Session.list(cwd).filter((x) => x.id !== agent.session.id);
          if (!list.length) return ui.info(grey("  No other sessions in this folder\n"));
          id = await ui.pick({
            title: "resume",
            items: list.slice(0, 50).map((x) => ({
              label: x.title || "(empty)",
              detail: `${x.id.slice(0, 8)} · ${new Date(x.mtime).toLocaleString()}`,
              value: x.id,
            })),
          });
          if (!id) return;
        }
        const found = Session.open(cwd, id);
        if (!found) return ui.error(`No session ${id}`);
        agent.session = found.session;
        agent.messages = found.messages;
        agent.lastContext = 0;
        agent.ctx.readFiles.clear();
        hub.report("session_id", found.session.id);
        return ui.notice(`Resumed ${found.session.id.slice(0, 8)} (${found.messages.length} messages)`);
      }
      case "cost": {
        const t = agent.totals;
        return ui.info(
          card(gradient("usage", [P.pink, P.violet]), [
            `${grey("model calls".padEnd(13))}${text(String(t.turns))}`,
            `${grey("input".padEnd(13))}${text(String(t.input))}`,
            `${grey("cached".padEnd(13))}${text(String(t.cacheRead))}`,
            `${grey("output".padEnd(13))}${text(String(t.output))}`,
          ], P.faint),
        );
      }
      case "mode": {
        let next = normalizeMode(arg);
        if (!arg) {
          next = await ui.pick({
            title: "approvals",
            items: MODE_ORDER.map((m) => ({ label: MODES[m].label, detail: MODES[m].hint, value: m })),
            current: agent.mode,
          });
          if (!next) return;
        }
        if (!next) return ui.error("Use /mode ask | auto-edit | auto (or press ⇧tab)");
        agent.mode = next;
        return ui.notice(`Approvals: ${MODES[next].label} · ${MODES[next].hint}`);
      }
      case "skills":
        if (!skills.length) return ui.info(grey("  No skills (~/.wowo/skills, ~/.claude/skills, .claude/skills)\n"));
        return ui.info(card(gradient("skills", [P.pink, P.violet]), skills.map((s) => `${accent("✦ " + s.name)} ${grey(s.description.slice(0, 80))}`), P.faint, grey("/<name> [request]")));
      case "todos":
        return agent.ctx.todos.length ? ui.todos(agent.ctx.todos) : ui.info(grey("  No todos\n"));
      case "exit":
      case "quit":
        process.exit(0);
      default: {
        const found = skills.find((s) => s.name === name);
        if (found) return run(`Load the \`${found.name}\` skill with the skill tool and follow it.${arg ? `\n\nRequest: ${arg}` : ""}`);
        return ui.error(`Unknown command /${name} (see /help)`);
      }
    }
  };

  if (opts.prompt) {
    ui.userMessage(opts.prompt);
    await run(opts.prompt);
  }

  for (;;) {
    const pending = typeahead.splice(0).join("");
    const reading = editor.read();
    if (pending) {
      const rest = editor.feed(pending);
      if (rest) typeahead.push(rest);
    }
    const line = await reading;
    if (line === null) break;
    const text = line.trim();
    if (!text) continue;
    if (/^\/[\w:-]+/.test(text)) {
      ui.commandEcho(text, editor.lastRows);
      await slash(text);
    } else {
      // The input and its rule turn into the prompt bubble.
      ui.userMessage(line.trim(), editor.lastRows);
      await run(text);
    }
  }
  process.exit(0);
}

main().catch((err) => {
  process.stdout.write("\x1b[?2004l");
  console.error(red(`wowo: ${err?.stack ?? err}`));
  process.exit(1);
});

export { c };
