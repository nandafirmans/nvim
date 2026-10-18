// Terminal UI: a gradient banner card, prompts as bubbles, the streamed
// reply with Markdown styling (headings, lists, quotes, code panels), tool
// calls with icons and coloured diffs, an approval card, a shimmering
// spinner with timer and token count, a status bar with a context gauge,
// and a line editor that takes bracketed paste (so multi-line prompts
// pasted by the hub arrive whole), history and Tab completion.
import { forest, wordmark } from "./brand.js";

const ESC = "\x1b[";

// Colours ------------------------------------------------------------------------------

const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const rgb = (h) => (s) => `\x1b[38;2;${hex(h).join(";")}m${s}\x1b[39m`;
const onRgb = (h) => (s) => `\x1b[48;2;${hex(h).join(";")}m${s}\x1b[49m`;

const P = {
  pink: "#ff6ac1",
  violet: "#a78bfa",
  blue: "#7aa2f7",
  cyan: "#7dd3fc",
  green: "#86efac",
  red: "#fca5a5",
  yellow: "#fde68a",
  orange: "#fdba74",
  text: "#e6e9f0",
  grey: "#8b93a7",
  faint: "#5c6378",
  panel: "#1b2131",
  bubble: "#2b3550",
  addBg: "#1f3b2c",
  delBg: "#47232b",
};

const c = {
  reset: "\x1b[0m",
  bold: (s) => `\x1b[1m${s}\x1b[22m`,
  dim: (s) => `\x1b[2m${s}\x1b[22m`,
  italic: (s) => `\x1b[3m${s}\x1b[23m`,
  under: (s) => `\x1b[4m${s}\x1b[24m`,
  strike: (s) => `\x1b[9m${s}\x1b[29m`,
};
const accent = rgb(P.pink);
const violet = rgb(P.violet);
const cyan = rgb(P.cyan);
const green = rgb(P.green);
const red = rgb(P.red);
const yellow = rgb(P.yellow);
const grey = rgb(P.grey);
const faint = rgb(P.faint);
const text = rgb(P.text);
const fireYellow = rgb("#ffd23f");
const fireOrange = rgb("#ff9f1c");

// Text whose colour runs through `stops`; `shift` slides the gradient.
function gradient(str, stops = [P.pink, P.violet, P.cyan], shift = 0) {
  const chars = [...str];
  const cols = stops.map(hex);
  return (
    chars
      .map((ch, i) => {
        if (ch === " ") return ch;
        let t = chars.length > 1 ? i / (chars.length - 1) : 0;
        t = (t + shift) % 1;
        const seg = Math.min(cols.length - 2, Math.floor(t * (cols.length - 1)));
        const local = t * (cols.length - 1) - seg;
        const [a, b] = [cols[seg], cols[seg + 1]];
        const mix = a.map((v, k) => Math.round(v + (b[k] - v) * local));
        return `\x1b[38;2;${mix.join(";")}m${ch}`;
      })
      .join("") + "\x1b[39m"
  );
}

const SPARK = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"];
const VERBS = ["Thinking", "Pondering", "Cooking", "Brewing", "Crafting", "Scheming", "Tinkering", "Conjuring"];

const ICONS = {
  read: ["◉", P.cyan],
  write: ["✚", P.green],
  edit: ["✎", P.yellow],
  bash: ["❯", P.orange],
  grep: ["⌕", P.blue],
  glob: ["⌕", P.blue],
  web_fetch: ["◍", P.cyan],
  task: ["⧉", P.violet],
  todo_write: ["☰", P.violet],
  skill: ["✦", P.pink],
};

// Approval modes, in the order Shift-Tab cycles them.
export const MODES = {
  ask: { label: "ask", hint: "asks before edits and commands", color: P.green },
  edits: { label: "auto-edit", hint: "edits files without asking", color: P.yellow },
  yolo: { label: "auto", hint: "runs everything without asking", color: P.red },
};
export const MODE_ORDER = ["ask", "edits", "yolo"];

// "auto" and "auto-edit" are the names shown; the old ones still work.
export function normalizeMode(mode) {
  const m = String(mode ?? "").toLowerCase();
  if (m === "auto" || m === "yolo" || m === "full") return "yolo";
  if (m === "auto-edit" || m === "autoedit" || m === "edits" || m === "edit") return "edits";
  if (m === "ask" || m === "") return "ask";
  return null;
}

const out = process.stdout;
const write = (s) => out.write(s);
const width = () => Math.max(40, out.columns || 100);
const boxWidth = () => Math.min(width() - 2, 96);

function visibleLength(s) {
  return [...s.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "")].length;
}

function pad(s, n) {
  return s + " ".repeat(Math.max(0, n - visibleLength(s)));
}

function cut(s, n) {
  const chars = [...s];
  return chars.length > n ? chars.slice(0, Math.max(0, n - 1)).join("") + "…" : s;
}

// Cuts coloured text to n visible characters, keeping the escape codes.
function cutAnsi(s, n) {
  let shown = 0;
  let out = "";
  for (const part of s.split(/(\x1b\[[0-9;?]*[A-Za-z])/)) {
    if (part.startsWith("\x1b[")) {
      out += part;
      continue;
    }
    for (const ch of part) {
      if (shown >= n - 1) return out + "…\x1b[0m";
      out += ch;
      shown++;
    }
  }
  return out;
}

function wrap(line, n) {
  if (visibleLength(line) <= n) return [line];
  if (line.includes("\x1b[")) return [cutAnsi(line, n)];
  const out = [];
  let rest = line;
  while ([...rest].length > n) {
    const chars = [...rest];
    let at = chars.slice(0, n).join("").lastIndexOf(" ");
    if (at < n * 0.5) at = n;
    out.push(chars.slice(0, at).join(""));
    rest = chars.slice(at).join("").replace(/^ /, "");
  }
  out.push(rest);
  return out;
}

function duration(ms) {
  const s = ms / 1000;
  return s < 60 ? `${s.toFixed(s < 10 ? 1 : 0)}s` : `${Math.floor(s / 60)}m ${Math.round(s % 60)}s`;
}

const k = (n) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n));

// Inline Markdown: `code`, **bold**, *italic*, ~~strike~~, [links](url).
function inline(line) {
  return line
    .replace(/`([^`]+)`/g, (_, code) => onRgb(P.panel)(cyan(` ${code} `)))
    .replace(/\*\*([^*]+)\*\*/g, (_, b) => c.bold(text(b)))
    .replace(/(^|[^*])\*([^*\s][^*]*)\*/g, (_, pre, i) => pre + c.italic(i))
    .replace(/~~([^~]+)~~/g, (_, s) => c.strike(s))
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, url) => `${c.under(cyan(label))} ${faint(url)}`);
}

// A rounded card: title in the top edge, lines inside.
function card(title, lines, color = P.violet, footer = "") {
  const w = boxWidth();
  const edge = rgb(color);
  const inner = w - 4;
  const top = `${edge("╭─")} ${title} ${edge("─".repeat(Math.max(0, w - visibleLength(title) - 5)) + "╮")}`;
  const body = lines.flatMap((l) => wrap(l, inner)).map((l) => `${edge("│")} ${pad(l, inner)} ${edge("│")}`);
  const bottomText = footer ? ` ${footer} ` : "";
  const bottom = edge("╰" + "─".repeat(Math.max(0, w - 2 - visibleLength(bottomText) - 1))) + bottomText + edge("─╯");
  return [top, ...body, bottom].join("\n") + "\n";
}

export class UI {
  constructor() {
    this.inCode = false;
    this.codeLang = "";
    this.pending = "";
    this.spinner = null;
    this.spinText = "";
    this.onKey = null; // set while a key is awaited (approval)
    this.turnStart = null;
    this.streamed = 0;
  }

  // Header ----------------------------------------------------------------------------

  // WOWO-AGENT in fire letters, then a card with the burning forest on the
  // left and the session, tools and skills on the right.
  banner({ model, cwd, branch, session, mode, resumed, skills = [], tools = [], version = "" }) {
    const home = process.env.HOME;
    const w = boxWidth();
    write("\n");
    for (const line of wordmark(width() - 2)) write(` ${line}\n`);
    // Wide: the forest beside the details. Narrow (a phone): a wide, low
    // forest above them, so neither gets squeezed.
    const stacked = w < 62;
    const art = w >= 84 ? forest(28, 14, 3) : !stacked ? forest(22, 11, 3) : [];
    const strip = stacked && w >= 30 ? forest(w - 4, 8, 3) : [];
    const artWidth = art.length ? visibleLength(art[0]) + 2 : 0;
    const room = w - 4 - artWidth;
    let where = cwd.startsWith(home) ? "~" + cwd.slice(home.length) : cwd;
    const folderRoom = room - 8 - (branch ? branch.length + 4 : 0);
    if (where.length > folderRoom) where = "…" + where.slice(-(folderRoom - 1));
    const heading = (s) => c.bold(fireYellow(s));
    const label = (s) => fireOrange(s.padEnd(8));
    const list = (names) => {
      const shown = [];
      let used = 0;
      for (const n of names) {
        if (used + n.length + 2 > room - 10 && shown.length) break;
        shown.push(n);
        used += n.length + 2;
      }
      const more = names.length - shown.length;
      return text(shown.join(", ")) + (more ? grey(`, +${more} more`) : "");
    };
    const group = (title, names) => {
      const have = names.filter((n) => tools.includes(n));
      return have.length ? `${fireOrange(title + ":")} ${text(have.join(", "))}` : null;
    };
    const modeColor = rgb(MODES[mode].color);
    const info = [
      heading("Session"),
      `${label("model")}${c.bold(text(model.ref))} ${faint(`${k(model.context)} ctx`)}`,
      `${label("folder")}${text(where)}${branch ? `  ${violet("⑂ " + branch)}` : ""}`,
      `${label("session")}${text(session.slice(0, 8))}${resumed ? ` ${cyan("resumed")}` : ""}  ${grey("approve")} ${modeColor(MODES[mode].label)}`,
      "",
      heading("Available Tools"),
      group("files", ["read", "write", "edit"]),
      group("search", ["grep", "glob", "web_fetch"]),
      group("shell", ["bash"]),
      group("agent", ["task", "todo_write", "skill"]),
      "",
      heading(`Skills (${skills.length})`),
      skills.length ? list(skills.map((s) => s.name)) : grey("none · add some to ~/.wowo/skills"),
    ].filter((l) => l !== null);
    const lines = strip.length ? [...strip, ""] : [];
    for (let i = 0; i < Math.max(art.length, info.length); i++) {
      const left = art.length ? pad(art[i] ?? "", artWidth) : "";
      const right = info[i] ?? "";
      lines.push(left + (visibleLength(right) > room ? cutAnsi(right, room) : right));
    }
    const title = c.bold(fireYellow(`WOWO-AGENT${version ? ` v${version}` : ""}`)) + grey(" · your keys, your agent");
    const footer = grey(`${tools.length} tools · ${skills.length} skills · /help for commands`);
    write(card(title, lines, "#ff9f1c", footer));
    write("\n");
  }

  // Prints a conversation again, as it looked live: prompts, replies, tool
  // calls and their results (after a resize redraws the screen).
  replay(messages, summaryOf = () => undefined) {
    for (const m of messages) {
      if (m.role === "user" && typeof m.content === "string") {
        if (m.content.startsWith("This session continues from an earlier conversation")) continue;
        this.userMessage(m.content);
      } else if (m.role === "assistant") {
        for (const part of m.content ?? []) {
          if (part.type === "text" && part.text?.trim()) {
            this.wroteText = false;
            this.pending = "";
            this.thinkingShown = false;
            this.text(part.text);
            this.endReply();
          } else if (part.type === "toolCall") {
            this.toolStart(part.name, part.arguments, summaryOf(part.name, part.arguments));
            this.unspin();
          }
        }
      } else if (m.role === "toolResult") {
        this.toolEnd(m.toolName, m.content?.map((c) => c.text).join("\n"), m.isError);
        this.unspin();
      }
    }
    this.turnStart = null;
    this.streamed = 0;
  }

  // The prompt just sent, as a bubble (replaces the editor's echo).
  userMessage(prompt, editorRows = 0) {
    if (editorRows > 0) write(`${ESC}${editorRows}A\r${ESC}J`);
    const w = boxWidth();
    const lines = prompt.split("\n").flatMap((l) => wrap(l, w - 4));
    const bubble = onRgb(P.bubble);
    lines.forEach((l, i) => {
      write(`${i === 0 ? accent("❯") : " "} ${bubble(" " + pad(text(l), w - 4) + " ")}\n`);
    });
    write("\n");
    this.turnStart = Date.now();
    this.streamed = 0;
  }

  // A slash command just typed: the input and its header become one dim line.
  commandEcho(command, editorRows = 0) {
    if (editorRows > 0) write(`${ESC}${editorRows}A\r${ESC}J`);
    write(`${accent("❯")} ${grey(command)}\n`);
  }

  // Picker -------------------------------------------------------------------------------------

  // An in-place menu: ↑/↓ (or Ctrl-P/N) move, typing filters, ⏎ picks, esc cancels.
  // items: [{ label, detail, value }]; resolves the value, or null.
  pick({ title, items, current, hint = "" }) {
    this.unspin();
    const maxRows = Math.min(12, Math.max(4, (out.rows || 30) - 8));
    let filter = "";
    let index = Math.max(0, items.findIndex((it) => it.value === current));
    let top = 0;
    let drawn = 0;
    const visible = () => items.filter((it) => !filter || `${it.label} ${it.detail ?? ""}`.toLowerCase().includes(filter.toLowerCase()));
    const draw = () => {
      if (drawn > 0) write(`${ESC}${drawn}A\r${ESC}J`);
      const list = visible();
      index = Math.min(index, Math.max(0, list.length - 1));
      if (index < top) top = index;
      if (index >= top + maxRows) top = index - maxRows + 1;
      const w = boxWidth() - 4;
      const lines = [];
      lines.push(filter ? `${violet("⌕")} ${text(filter)}${accent("▏")}` : faint("⌕ type to filter"));
      if (!list.length) lines.push(grey("  nothing matches"));
      list.slice(top, top + maxRows).forEach((it, i) => {
        const at = top + i === index;
        const mark = it.value === current ? accent(" ◆") : "";
        const body = `${at ? accent("❯") : " "} ${at ? c.bold(text(it.label)) : grey(it.label)}${mark} ${faint(it.detail ?? "")}`;
        lines.push(at ? onRgb(P.bubble)(pad(cutAnsi(body, w), w)) : cutAnsi(body, w));
      });
      const more = list.length > maxRows ? `${index + 1}/${list.length} · ` : "";
      const block = card(gradient(title, [P.pink, P.violet]), lines, P.faint, grey(`${more}↑↓ move · ⏎ pick · esc cancel${hint}`));
      write(block);
      drawn = block.split("\n").length - 1;
    };
    draw();
    return new Promise((resolve) => {
      const finish = (value) => {
        this.onKey = null;
        if (drawn > 0) write(`${ESC}${drawn}A\r${ESC}J`);
        resolve(value);
      };
      this.onKey = (key) => {
        const list = visible();
        if (key === "\r") return finish(list[index]?.value ?? null);
        if (key === "\x1b" || key === "\x03") return finish(null);
        if (key === "\x1b[A" || key === "\x1bOA" || key === "\x10") index = Math.max(0, index - 1);
        else if (key === "\x1b[B" || key === "\x1bOB" || key === "\x0e") index = Math.min(list.length - 1, index + 1);
        else if (key === "\x1b[5~") index = Math.max(0, index - maxRows);
        else if (key === "\x1b[6~") index = Math.min(list.length - 1, index + maxRows);
        else if (key === "\x7f" || key === "\b") filter = filter.slice(0, -1);
        else if (key.length === 1 && key >= " ") {
          filter += key;
          index = 0;
          top = 0;
        } else return;
        draw();
      };
    });
  }

  // The line above the input: the approval mode and the keys.
  inputHeader(mode) {
    const m = MODES[mode];
    const tint = rgb(m.color);
    const badge = mode === "ask" ? `${tint("●")} ${grey("ask")}` : `${tint("⏵⏵")} ${c.bold(tint(m.label))} ${grey("on")}`;
    const left = ` ${badge} ${faint("· ⇧tab mode")} `;
    const w = boxWidth();
    // Narrow screens get the short hint, so the line never wraps.
    const hint = w >= 70 ? " ⏎ send · \\⏎ newline · / commands " : w >= 46 ? " ⏎ send · / cmds " : " ";
    const fill = Math.max(1, w - visibleLength(left) - hint.length - 1);
    return faint("─") + left + faint("─".repeat(fill) + hint);
  }

  // Spinner ------------------------------------------------------------------------------

  spin(label) {
    if (label) this.spinText = label;
    if (this.spinner) return;
    let i = 0;
    const verb = VERBS[Math.floor(Math.random() * VERBS.length)];
    const draw = () => {
      const elapsed = this.turnStart ? duration(Date.now() - this.turnStart) : "";
      const word = this.spinText === "Thinking…" ? `${verb}…` : this.spinText;
      const shimmer = gradient(word, [P.violet, P.pink, P.yellow, P.pink, P.violet], (i % 30) / 30);
      // One line, always: a line that wraps leaves its first half behind on
      // every frame (\r only returns to the start of the last row).
      const room = width() - 1;
      const parts = [elapsed, this.streamed ? `↓ ${k(Math.round(this.streamed / 4))} tokens` : "", "esc to interrupt"].filter(Boolean);
      let line;
      do {
        const stats = parts.length ? ` ${faint(`(${parts.join(" · ")})`)}` : "";
        line = `${accent(SPARK[i % SPARK.length])} ${shimmer}${stats}`;
      } while (visibleLength(line) > room && parts.pop() !== undefined);
      if (visibleLength(line) > room) line = cutAnsi(line, room);
      write(`\r${ESC}2K${line}`);
      i++;
    };
    draw();
    this.spinner = setInterval(draw, 110);
  }

  unspin() {
    if (!this.spinner) return;
    clearInterval(this.spinner);
    this.spinner = null;
    write(`\r${ESC}2K`);
  }

  // Reply ------------------------------------------------------------------------------------

  startReply() {
    this.pending = "";
    this.thinkingShown = false;
    this.wroteText = false;
    this.turnStart ??= Date.now();
    this.spin("Thinking…");
  }

  // Reasoning: the first few lines, dimmed, printed only as whole lines so
  // the spinner below never overwrites a half-written one.
  thinking(chunk) {
    this.streamed += chunk.length;
    if (!this.thinkingShown) {
      this.unspin();
      write(`${violet("∴")} ${c.italic(grey("thinking"))}\n`);
      this.thinkingShown = true;
      this.thinkingLines = 0;
      this.thinkBuf = "";
    }
    this.thinkBuf += chunk;
    const w = boxWidth() - 4;
    for (;;) {
      const nl = this.thinkBuf.indexOf("\n");
      let lineEnd = nl >= 0 && nl <= w ? nl : [...this.thinkBuf].length > w ? this.thinkBuf.lastIndexOf(" ", w) : -1;
      if (lineEnd < 0 && [...this.thinkBuf].length > w) lineEnd = w;
      if (lineEnd < 0) break;
      this.thinkLine(this.thinkBuf.slice(0, lineEnd));
      this.thinkBuf = this.thinkBuf.slice(lineEnd + (this.thinkBuf[lineEnd] === "\n" || this.thinkBuf[lineEnd] === " " ? 1 : 0));
    }
    this.spin();
  }

  thinkLine(line) {
    if (!line.trim()) return;
    if (this.thinkingLines < 3) {
      this.unspin();
      write(`${faint("│")} ${c.italic(faint(line))}\n`);
    } else if (this.thinkingLines === 3) {
      this.unspin();
      write(`${faint("│ …")}\n`);
    }
    this.thinkingLines++;
  }

  flushThinking() {
    if (this.thinkingShown && this.thinkBuf) {
      this.thinkLine(this.thinkBuf);
      this.thinkBuf = "";
    }
  }

  text(chunk) {
    this.streamed += chunk.length;
    this.unspin();
    if (!this.wroteText) {
      this.flushThinking();
      if (this.thinkingShown) write("\n");
      write(`${gradient("◆", [P.pink, P.violet])} `);
      this.firstLine = true;
    }
    this.wroteText = true;
    this.pending += chunk;
    let index;
    while ((index = this.pending.indexOf("\n")) >= 0) {
      this.line(this.pending.slice(0, index));
      this.pending = this.pending.slice(index + 1);
    }
  }

  // One complete line of the reply.
  line(raw) {
    const indent = this.firstLine ? "" : "  ";
    this.firstLine = false;
    const fence = raw.match(/^\s*```(\S*)/);
    const w = boxWidth() - 2;
    if (fence) {
      if (!this.inCode) {
        this.inCode = true;
        this.codeLang = fence[1];
        const label = this.codeLang ? ` ${this.codeLang} ` : "";
        write(`${indent}${faint("╭" + label + "─".repeat(Math.max(0, w - label.length - 2)))}\n`);
      } else {
        this.inCode = false;
        write(`${indent}${faint("╰" + "─".repeat(w - 2))}\n`);
      }
      return;
    }
    if (this.inCode) {
      write(`${indent}${faint("│")}${onRgb(P.panel)(cyan(pad(" " + cut(raw, w - 3), w - 1)))}\n`);
      return;
    }
    const heading = raw.match(/^(#{1,6})\s+(.*)$/);
    if (heading) {
      const level = heading[1].length;
      const title = level === 1 ? gradient(heading[2].toUpperCase(), [P.pink, P.violet]) : level === 2 ? c.bold(accent(heading[2])) : c.bold(violet(heading[2]));
      write(`${indent}${c.bold(title)}\n`);
      return;
    }
    if (/^\s*([-*_])\s*\1\s*\1[\s\1]*$/.test(raw)) {
      write(`${indent}${faint("─".repeat(Math.min(40, w)))}\n`);
      return;
    }
    const quote = raw.match(/^>\s?(.*)$/);
    if (quote) {
      write(`${indent}${violet("▌")} ${c.italic(grey(inline(quote[1])))}\n`);
      return;
    }
    const bullet = raw.match(/^(\s*)[-*+]\s+(\[[ xX]\]\s+)?(.*)$/);
    if (bullet) {
      const box = bullet[2] ? (bullet[2].includes("x") || bullet[2].includes("X") ? green("✔ ") : grey("○ ")) : "";
      const mark = box || accent(bullet[1].length ? "◦ " : "• ");
      this.flow(`${indent}${bullet[1]}${mark}`, bullet[3]);
      return;
    }
    const numbered = raw.match(/^(\s*)(\d+)[.)]\s+(.*)$/);
    if (numbered) {
      this.flow(`${indent}${numbered[1]}${violet(numbered[2] + ".")} `, numbered[3]);
      return;
    }
    if (/^\s*\|.*\|\s*$/.test(raw)) {
      if (/^\s*\|[\s:|-]+\|\s*$/.test(raw)) {
        write(`${indent}${faint(raw.replace(/[^|]/g, "─").replace(/\|/g, "┼"))}\n`);
        return;
      }
      write(`${indent}${raw.replace(/\|/g, faint("│")).replace(/[^│]+/g, (cell) => inline(cell))}\n`);
      return;
    }
    this.flow(indent, raw);
  }

  // Text after a prefix, wrapped at word boundaries to the screen with a
  // hanging indent (the terminal's own wrap splits words and drops the indent).
  flow(prefix, body) {
    const lead = visibleLength(prefix);
    const room = Math.max(10, width() - 1 - lead);
    wrap(body, room).forEach((piece, i) => {
      write(`${i === 0 ? prefix : " ".repeat(lead)}${inline(piece)}\n`);
    });
  }

  endReply() {
    this.unspin();
    this.flushThinking();
    if (this.pending) {
      this.line(this.pending);
      this.pending = "";
    }
    if (this.inCode) {
      write(`  ${faint("╰" + "─".repeat(boxWidth() - 4))}\n`);
      this.inCode = false;
    }
    if (this.wroteText) write("\n");
  }

  // Tools ------------------------------------------------------------------------------------

  toolStart(name, args, summary) {
    this.unspin();
    if (name === "todo_write") return; // todos() draws the plan itself
    const [icon, color] = ICONS[name] ?? ["●", P.grey];
    const label = String(summary ?? args?.path ?? args?.pattern ?? args?.url ?? args?.description ?? "").split("\n")[0];
    const tint = rgb(color);
    write(`${tint(icon)} ${c.bold(tint(name))} ${text(cut(label, boxWidth() - name.length - 4))}\n`);
    this.spin(name === "bash" ? "Running…" : "Working…");
  }

  toolEnd(name, result, isError) {
    this.unspin();
    const lines = String(result ?? "").split("\n");
    const w = boxWidth() - 6;
    if (name === "edit" && !isError) {
      const diff = lines.slice(1, 40);
      let adds = 0;
      let dels = 0;
      for (const l of diff) {
        const m = l.match(/^([-+ ]) (\d+) (.*)$/);
        if (!m) continue;
        const [, sign, num, body] = m;
        const n = faint(num.padStart(4));
        if (sign === "+") {
          adds++;
          write(`  ${faint("┃")}${n} ${onRgb(P.addBg)(green(pad("+ " + cut(body, w - 7), w - 5)))}\n`);
        } else if (sign === "-") {
          dels++;
          write(`  ${faint("┃")}${n} ${onRgb(P.delBg)(red(pad("- " + cut(body, w - 7), w - 5)))}\n`);
        } else {
          write(`  ${faint("┃")}${n}   ${grey(cut(body, w - 7))}\n`);
        }
      }
      write(`  ${faint("┗")} ${green(`+${adds}`)} ${red(`-${dels}`)}\n`);
    } else if (name === "read" || name === "skill") {
      write(`  ${faint("┗")} ${grey(isError ? lines[0] : `${lines.length} lines`)}\n`);
    } else if (name === "todo_write") {
      // The list itself is drawn by todos().
    } else {
      const shown = lines.slice(0, 5);
      const tint = isError ? red : grey;
      shown.forEach((l, i) => {
        const branch = i === shown.length - 1 && lines.length <= 5 ? "┗" : "┃";
        write(`  ${faint(branch)} ${tint(cut(l, w))}\n`);
      });
      if (lines.length > 5) write(`  ${faint("┗")} ${faint(`… ${lines.length - 5} more lines`)}\n`);
    }
    this.spin("Thinking…");
  }

  subTool(name, args) {
    const [icon] = ICONS[name] ?? ["●"];
    this.spinText = `task ${icon} ${name} ${cut(String(args?.path ?? args?.pattern ?? args?.command ?? ""), 40)}`;
  }

  todos(list) {
    this.unspin();
    const done = list.filter((t) => t.status === "completed").length;
    const barW = 16;
    const filled = list.length ? Math.round((done / list.length) * barW) : 0;
    const bar = gradient("━".repeat(filled), [P.violet, P.green]) + faint("━".repeat(barW - filled));
    write(`  ${violet("☰")} ${c.bold(text("Plan"))} ${bar} ${grey(`${done}/${list.length}`)}\n`);
    for (const t of list) {
      const mark = t.status === "completed" ? green("✔") : t.status === "in_progress" ? yellow("◐") : faint("○");
      const label = t.status === "completed" ? c.strike(faint(t.content)) : t.status === "in_progress" ? c.bold(text(t.content)) : grey(t.content);
      write(`    ${mark} ${label}\n`);
    }
  }

  notice(msg) {
    this.unspin();
    write(`${yellow("›")} ${grey(msg)}\n`);
  }

  error(msg) {
    this.unspin();
    write(card(red(c.bold("error")), String(msg).split("\n").map((l) => red(l)), P.red));
  }

  info(msg) {
    this.unspin();
    write(msg + "\n");
  }

  usage(tokens, context) {
    this.lastUsage = { tokens, context };
  }

  // Status bar after a prompt: time, model, context gauge, tokens.
  footer(model, totals) {
    const u = this.lastUsage;
    const pct = u ? Math.min(100, Math.round((u.tokens * 100) / u.context)) : 0;
    const barW = 10;
    const filled = Math.round((pct / 100) * barW);
    const gaugeColor = pct >= 80 ? P.red : pct >= 60 ? P.yellow : P.green;
    const gauge = rgb(gaugeColor)("▰".repeat(filled)) + faint("▱".repeat(barW - filled));
    const took = this.turnStart ? duration(Date.now() - this.turnStart) : "";
    const parts = [
      green("✓") + " " + text(took || "done"),
      violet("◆") + " " + text(model.ref),
      `${gauge} ${rgb(gaugeColor)(pct + "%")}`,
      faint(`↑${k(totals.input + totals.cacheRead)} ↓${k(totals.output)}`),
    ];
    write(`  ${parts.join(faint("  │  "))}\n\n`);
    this.turnStart = null;
    this.streamed = 0;
  }

  // Approval -----------------------------------------------------------------------------------

  approve(name, args, signal) {
    this.unspin();
    const [icon, color] = ICONS[name] ?? ["●", P.grey];
    const lines = [];
    const w = boxWidth() - 6;
    if (name === "bash") {
      lines.push(grey(args.description ?? "Run a command"));
      for (const l of String(args.command ?? "").split("\n").slice(0, 8)) lines.push(rgb(P.orange)("$ ") + text(l));
    } else if (name === "write") {
      const body = String(args.content ?? "").split("\n");
      lines.push(`${grey("create / overwrite")} ${text(args.path)} ${faint(`(${body.length} lines)`)}`);
      for (const l of body.slice(0, 8)) lines.push(onRgb(P.addBg)(green(pad("+ " + cut(l, w - 4), w - 2))));
      if (body.length > 8) lines.push(faint(`… ${body.length - 8} more lines`));
    } else if (name === "edit") {
      lines.push(`${grey("edit")} ${text(args.path)}`);
      for (const l of String(args.old_string ?? "").split("\n").slice(0, 8)) lines.push(onRgb(P.delBg)(red(pad("- " + cut(l, w - 4), w - 2))));
      for (const l of String(args.new_string ?? "").split("\n").slice(0, 8)) lines.push(onRgb(P.addBg)(green(pad("+ " + cut(l, w - 4), w - 2))));
    } else {
      lines.push(text(cut(JSON.stringify(args), 300)));
    }
    const key = (k, label) => `${onRgb(P.bubble)(c.bold(text(` ${k} `)))} ${grey(label)}`;
    lines.push("");
    lines.push([key("y", "yes"), key("a", "always"), key("n", "no"), key("t", "say why"), key("⇧tab", "auto mode")].join("  "));
    write(card(`${rgb(color)(icon)} ${c.bold(yellow(`Allow ${name}?`))}`, lines, P.yellow));
    return new Promise((resolve) => {
      const done = (answer) => {
        this.onKey = null;
        resolve(answer);
      };
      signal?.addEventListener("abort", () => done({ choice: "no" }));
      this.onKey = (key) => {
        if (key === "y" || key === "Y" || key === "\r") {
          write(`  ${green("✓ allowed")}\n`);
          done({ choice: "yes" });
        } else if (key === "a" || key === "A") {
          write(`  ${green(`✓ allowed ${name} for this session`)}\n`);
          done({ choice: "always" });
        } else if (key === "\x1b[Z") {
          write(`  ${red("⏵⏵ auto mode on")} ${grey("· ⇧tab at the prompt changes it")}\n`);
          done({ choice: "auto" });
        } else if (key === "n" || key === "N" || key === "\x1b") {
          write(`  ${red("✗ declined")}\n`);
          done({ choice: "no" });
        } else if (key === "t" || key === "T") {
          this.onKey = null;
          this.editor.ask("  tell wowo › ").then((reason) => {
            write(`  ${red("✗ declined")}\n`);
            resolve({ choice: "no", reason });
          });
        }
      };
    });
  }
}

// Line editor -------------------------------------------------------------------------

const PASTE_START = "\x1b[200~";
const PASTE_END = "\x1b[201~";

export class Editor {
  constructor({ complete }) {
    // (text before the cursor) -> { token, items: [{ value, desc, kind }] } or null:
    // the live suggestion menu under the input.
    this.complete = complete;
    this.menuIndex = 0;
    this.menuKey = null;
    this.menuDismissed = null;
    this.history = [];
    this.buffer = "";
    this.cursor = 0;
    this.rows = 0;
    this.cursorRow = 0;
    this.prompt = "❯ ";
    this.resolve = null;
    this.pasting = null;
  }

  // Reads one input; resolves the text (or null on Ctrl-D). `header()`, when
  // set, draws a line above the input (redrawn with it).
  read(prompt = "❯ ", header = this.header) {
    this.prompt = prompt;
    this.currentHeader = header;
    this.buffer = "";
    this.cursor = 0;
    this.historyIndex = this.history.length;
    this.rows = 0;
    this.cursorRow = 0; // a new input starts on a fresh line
    this.render();
    return new Promise((resolve) => {
      this.resolve = resolve;
    });
  }

  // A one-line question (approval reasons).
  ask(prompt) {
    const saved = this.history;
    this.history = [];
    return this.read(prompt, null).then((text) => {
      this.history = saved;
      return text ?? "";
    });
  }

  get active() {
    return this.resolve !== null;
  }

  finish(value) {
    this.cursor = this.buffer.length;
    this.menuDismissed = this.buffer; // no menu left under a sent input
    this.render();
    write("\n");
    this.lastRows = this.rows;
    const resolve = this.resolve;
    this.resolve = null;
    this.rows = 0;
    if (value && value.trim() && this.prompt === "❯ ") this.history.push(value);
    resolve(value);
  }

  insert(text) {
    this.buffer = this.buffer.slice(0, this.cursor) + text + this.buffer.slice(this.cursor);
    this.cursor += text.length;
  }

  // The suggestions for the word at the cursor, or null.
  menu() {
    if (!this.complete || this.cursor !== this.buffer.length && !/\s/.test(this.buffer[this.cursor] ?? " ")) return null;
    const before = this.buffer.slice(0, this.cursor);
    if (this.menuDismissed === before) return null;
    if (this.menuKey !== before) {
      this.menuKey = before;
      this.menuIndex = 0;
      this.menuCache = this.complete(before);
    }
    const m = this.menuCache;
    return m && m.items.length ? m : null;
  }

  accept(item, token) {
    const before = this.buffer.slice(0, this.cursor);
    const start = before.length - token.length;
    const value = item.value + " ";
    this.buffer = this.buffer.slice(0, start) + value + this.buffer.slice(this.cursor);
    this.cursor = start + value.length;
  }

  // Lines of the buffer as shown, each with its prefix.
  layout() {
    const cols = width();
    const lines = this.buffer.split("\n");
    let rows = 0;
    let cursorRow = 0;
    let cursorCol = 0;
    let offset = 0;
    const shown = [];
    if (this.currentHeader) {
      shown.push(this.currentHeader());
      rows = 1;
    }
    lines.forEach((line, i) => {
      const prefix = i === 0 ? this.prompt : "  ";
      const text = prefix + line;
      const lineRows = Math.max(1, Math.ceil((text.length + 1) / cols));
      if (this.cursor >= offset && this.cursor <= offset + line.length) {
        const col = prefix.length + (this.cursor - offset);
        cursorRow = rows + Math.floor(col / cols);
        cursorCol = col % cols;
      }
      shown.push(i === 0 ? accent(this.prompt) + line : grey(prefix) + line);
      rows += lineRows;
      offset += line.length + 1;
    });
    const m = this.resolve ? this.menu() : null;
    if (m) {
      const max = 8;
      this.menuIndex = Math.min(this.menuIndex, m.items.length - 1);
      const top = Math.max(0, Math.min(this.menuIndex - max + 1, m.items.length - max));
      const nameW = Math.min(30, Math.max(...m.items.slice(top, top + max).map((it) => [...it.value].length)) + 2);
      m.items.slice(top, top + max).forEach((it, i) => {
        const at = top + i === this.menuIndex;
        const tag = it.kind === "skill" ? accent("✦") : it.kind === "file" ? cyan("◉") : violet("◇");
        const label = cut(it.value, nameW - 1);
        const name = pad(at ? c.bold(text(label)) : grey(label), nameW);
        let line = `  ${at ? accent("❯") : " "} ${tag} ${name}${faint(it.desc ?? "")}`;
        line = cutAnsi(line, cols - 1);
        shown.push(at ? onRgb(P.bubble)(pad(line, cols - 1)) : line);
        rows += 1;
      });
      const extra = m.items.length > max ? `${this.menuIndex + 1}/${m.items.length} · ` : "";
      shown.push(faint(`    ${extra}↑↓ select · tab complete · ⏎ ${m.token.startsWith("/") ? "run" : "insert"} · esc hide`));
      rows += 1;
    }
    return { shown, rows, cursorRow, cursorCol };
  }

  render() {
    // Back to the first row of the previous render, clear it, draw again.
    if (this.cursorRow > 0) write(`${ESC}${this.cursorRow}A`);
    write(`\r${ESC}J`);
    const { shown, rows, cursorRow, cursorCol } = this.layout();
    write(shown.join("\n"));
    const lastRow = rows - 1;
    if (lastRow > cursorRow) write(`${ESC}${lastRow - cursorRow}A`);
    write(`\r${cursorCol > 0 ? `${ESC}${cursorCol}C` : ""}`);
    this.rows = rows;
    this.cursorRow = cursorRow;
  }

  // Handles one chunk of stdin while reading.
  feed(data) {
    let s = data;
    while (s.length) {
      if (this.pasting !== null) {
        const end = s.indexOf(PASTE_END);
        if (end < 0) {
          this.pasting += s;
          return;
        }
        this.pasting += s.slice(0, end);
        this.insert(this.pasting.replace(/\r\n?/g, "\n"));
        this.pasting = null;
        s = s.slice(end + PASTE_END.length);
        continue;
      }
      if (s.startsWith(PASTE_START)) {
        this.pasting = "";
        s = s.slice(PASTE_START.length);
        continue;
      }
      const seq = s.match(/^\x1b\[[0-9;]*[A-Za-z~]|^\x1b[\r\n]|^\x1b./)?.[0];
      const key = seq ?? s[0];
      s = s.slice(key.length);
      if (this.key(key) === "submitted") return s;
    }
    this.render();
    return "";
  }

  key(k) {
    const m = this.menu();
    if (m) {
      const item = m.items[this.menuIndex];
      if (k === "\x1b[A" || k === "\x1bOA" || k === "\x10") {
        this.menuIndex = (this.menuIndex - 1 + m.items.length) % m.items.length;
        return;
      }
      if (k === "\x1b[B" || k === "\x1bOB" || k === "\x0e") {
        this.menuIndex = (this.menuIndex + 1) % m.items.length;
        return;
      }
      if (k === "\t") {
        this.accept(item, m.token);
        return;
      }
      if (k === "\r") {
        if (m.token.startsWith("/") && this.buffer.slice(0, this.cursor).trim() === m.token) {
          // Run the highlighted command, as typed in full.
          this.buffer = item.value;
          this.cursor = this.buffer.length;
          this.finish(this.buffer);
          return "submitted";
        }
        if (!m.token.startsWith("/")) {
          this.accept(item, m.token);
          return;
        }
      }
      if (k === "\x1b") {
        this.menuDismissed = this.buffer.slice(0, this.cursor);
        return;
      }
    }
    const b = this.buffer;
    switch (k) {
      case "\r":
        if (b.endsWith("\\") && this.cursor === b.length) {
          this.buffer = b.slice(0, -1);
          this.cursor = this.buffer.length;
          this.insert("\n");
          return;
        }
        this.finish(b);
        return "submitted";
      case "\n":
      case "\x1b\r":
        this.insert("\n");
        return;
      case "\x7f":
      case "\b":
        if (this.cursor > 0) {
          this.buffer = b.slice(0, this.cursor - 1) + b.slice(this.cursor);
          this.cursor--;
        }
        return;
      case "\x1b[3~":
        this.buffer = b.slice(0, this.cursor) + b.slice(this.cursor + 1);
        return;
      case "\x1b[D":
        this.cursor = Math.max(0, this.cursor - 1);
        return;
      case "\x1b[C":
        this.cursor = Math.min(b.length, this.cursor + 1);
        return;
      case "\x1b[H":
      case "\x01":
        this.cursor = b.lastIndexOf("\n", this.cursor - 1) + 1;
        return;
      case "\x1b[F":
      case "\x05": {
        const end = b.indexOf("\n", this.cursor);
        this.cursor = end < 0 ? b.length : end;
        return;
      }
      case "\x1b[A":
      case "\x1b[B": {
        if (b.includes("\n")) return;
        const step = k === "\x1b[A" ? -1 : 1;
        const next = this.historyIndex + step;
        if (next < 0 || next > this.history.length) return;
        this.historyIndex = next;
        this.buffer = this.history[next] ?? "";
        this.cursor = this.buffer.length;
        return;
      }
      case "\x15":
        this.buffer = b.slice(this.cursor);
        this.cursor = 0;
        return;
      case "\x0b":
        this.buffer = b.slice(0, this.cursor);
        return;
      case "\x17": {
        const before = b.slice(0, this.cursor).replace(/\S+\s*$/, "");
        this.buffer = before + b.slice(this.cursor);
        this.cursor = before.length;
        return;
      }
      case "\x03":
        if (b) {
          this.buffer = "";
          this.cursor = 0;
          return;
        }
        write(grey("\n(Ctrl-D or /exit quits)\n"));
        this.rows = 0;
        this.cursorRow = 0;
        return;
      case "\x04":
        if (!b) {
          this.finish(null);
          return "submitted";
        }
        return;
      case "\x1b[Z":
        this.onShiftTab?.();
        return;
      default:
        if (k.length === 1 && k >= " ") this.insert(k);
        else if (k.length > 1 && !k.startsWith("\x1b")) this.insert(k);
    }
  }
}

export { c, P, accent, violet, cyan, green, red, yellow, grey, faint, text, gradient, card, visibleLength };
