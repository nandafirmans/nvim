// The agent loop: send the conversation, stream the reply, run the tool
// calls it asks for (with approval where needed), feed the results back,
// and repeat until the model answers without tools. Compacts the
// conversation when the context window fills up.
import { complete } from "./providers.js";
import * as hub from "./hub.js";
import { systemPrompt } from "./prompt.js";
import { READ_ONLY, TOOLS, isSafeCommand } from "./tools.js";

const MAX_TURNS = 200;
const COMPACT_AT = 0.8;

const SUMMARY_REQUEST = `Write a handover summary of this conversation so the work can continue in a fresh context. Include:
1. The user's requests and intent, in order, quoting exact wording where it matters.
2. Key decisions, constraints and preferences the user stated.
3. Files read, created or changed, with what changed and why.
4. Commands run and their important results (errors, test results).
5. What is done, what is in progress, and the exact next step.
Be specific (paths, names, numbers). No preamble.`;

export class Agent {
  constructor({ config, model, provider, cwd, session, messages = [], ui, skills = [] }) {
    this.config = config;
    this.model = model;
    this.provider = provider;
    this.cwd = cwd;
    this.session = session;
    this.messages = messages;
    this.ui = ui;
    this.skills = skills;
    this.mode = config.permissions; // ask | edits | yolo
    this.allowed = new Set(); // tools approved "always" this session
    this.ctx = { cwd, readFiles: new Map(), todos: [], ui, skills, subagent: (p) => this.subagent(p) };
    this.totals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, turns: 0 };
    this.lastContext = 0;
    this.controller = null;
  }

  get busy() {
    return this.controller !== null;
  }

  interrupt() {
    this.controller?.abort(new Error("interrupted"));
  }

  system() {
    return systemPrompt({ cwd: this.cwd, model: this.model, instructions: this.config.instructions, skills: this.skills });
  }

  push(message) {
    this.messages.push(message);
    this.session?.message(message);
  }

  // Runs one user prompt to the end. Resolves "done", "interrupted", "limited" or "error".
  async prompt(text) {
    this.controller = new AbortController();
    const signal = this.controller.signal;
    this.ctx.signal = signal;
    hub.report("task", text.split("\n").find((l) => l.trim()) ?? text);
    hub.status("running", "Thinking…");
    this.push({ role: "user", content: text });
    try {
      for (let turn = 0; turn < MAX_TURNS; turn++) {
        if (this.lastContext > this.model.context * COMPACT_AT) await this.compact(signal);
        const reply = await this.turn(signal);
        const calls = reply.content.filter((p) => p.type === "toolCall");
        if (!calls.length) {
          if (reply.stopReason === "length") this.ui.notice("The reply hit the output limit; say “continue” to go on.");
          break;
        }
        for (const call of calls) {
          if (signal.aborted) throw signal.reason;
          this.push(await this.runTool(call, signal));
        }
      }
      hub.status("done", "");
      return "done";
    } catch (err) {
      if (signal.aborted) {
        this.closeOpenCalls();
        this.ui.notice("Interrupted · tell wowo what to do differently");
        hub.status("idle", "");
        return "interrupted";
      }
      const message = err?.message ?? String(err);
      this.ui.error(message);
      if (/usage limit|limit reached|quota|credit|insufficient|HTTP 429/i.test(message)) {
        hub.status("limited", message);
        return "limited";
      }
      hub.status("done", "");
      return "error";
    } finally {
      this.controller = null;
    }
  }

  // A tool call without a result breaks the next request; answer it.
  closeOpenCalls() {
    const last = this.messages[this.messages.length - 1];
    if (last?.role !== "assistant") return;
    for (const call of last.content.filter((p) => p.type === "toolCall")) {
      this.push({ role: "toolResult", toolCallId: call.id, toolName: call.name, content: [{ type: "text", text: "Interrupted by the user." }], isError: true });
    }
  }

  async turn(signal) {
    this.ui.startReply();
    const reply = await complete({
      provider: this.provider,
      model: this.model,
      system: this.system(),
      messages: this.messages,
      tools: TOOLS,
      signal,
      onText: (t) => this.ui.text(t),
      onThinking: (t) => this.ui.thinking(t),
      onRetry: (msg, seconds) => this.ui.notice(`${msg} · retrying in ${seconds}s`),
    });
    this.ui.endReply();
    const message = { role: "assistant", content: reply.content, usage: reply.usage, model: this.model.id, stopReason: reply.stopReason };
    this.push(message);
    this.track(reply.usage);
    return reply;
  }

  track(usage) {
    this.totals.input += usage.input;
    this.totals.output += usage.output;
    this.totals.cacheRead += usage.cacheRead;
    this.totals.cacheWrite += usage.cacheWrite;
    this.totals.turns += 1;
    this.lastContext = usage.input + usage.cacheRead + usage.cacheWrite + usage.output;
    this.ui.usage?.(this.lastContext, this.model.context);
  }

  needsApproval(tool, args) {
    if (tool.readOnly || this.mode === "yolo" || this.allowed.has(tool.name)) return false;
    if (tool.safe?.(args)) return false;
    if (this.mode === "edits" && (tool.name === "edit" || tool.name === "write")) return false;
    return true;
  }

  async runTool(call, signal) {
    const tool = TOOLS.find((t) => t.name === call.name);
    const result = (text, isError) => ({
      role: "toolResult",
      toolCallId: call.id,
      toolName: call.name,
      content: [{ type: "text", text }],
      isError: Boolean(isError),
    });
    if (!tool) return result(`Unknown tool ${call.name}. Available: ${TOOLS.map((t) => t.name).join(", ")}`, true);
    if (call.arguments?.__invalid_json !== undefined) {
      return result("The arguments were not valid JSON (maybe cut off by the output limit). Send the call again, smaller.", true);
    }
    this.ui.toolStart(call.name, call.arguments, tool.summary?.(call.arguments));
    hub.report("activity", hub.describe(call.name, call.arguments));
    if (this.needsApproval(tool, call.arguments)) {
      hub.status("waiting", `approve ${call.name} ${tool.summary?.(call.arguments) ?? ""}`);
      const answer = await this.ui.approve(call.name, call.arguments, signal);
      hub.status("running");
      if (answer.choice === "always") this.allowed.add(tool.name);
      if (answer.choice === "auto") {
        this.mode = "yolo";
        this.onModeChange?.(this.mode);
      }
      if (answer.choice === "no") {
        const why = answer.reason ? ` The user said: ${answer.reason}` : "";
        this.ui.toolEnd(call.name, "declined", true);
        return result(`The user declined this ${call.name} call.${why}`, true);
      }
    }
    try {
      const out = await tool.run(call.arguments ?? {}, this.ctx);
      this.ui.toolEnd(call.name, out.text, out.isError);
      return result(out.text, out.isError);
    } catch (err) {
      if (signal.aborted) throw signal.reason;
      this.ui.toolEnd(call.name, err.message, true);
      return result(`Error: ${err.message}`, true);
    }
  }

  // Replaces the conversation with a summary of it.
  async compact(signal, focus) {
    if (this.messages.length < 2) return;
    this.ui.notice("Compacting the conversation…");
    hub.report("activity", "Compacting");
    this.closeOpenCalls();
    const request = focus ? `${SUMMARY_REQUEST}\nFocus especially on: ${focus}` : SUMMARY_REQUEST;
    const reply = await complete({
      provider: this.provider,
      model: this.model,
      system: "You summarize coding sessions for handover. Output only the summary.",
      messages: [...this.messages, { role: "user", content: request }],
      tools: [],
      signal,
    });
    const summary = reply.content.filter((p) => p.type === "text").map((p) => p.text).join("\n").trim();
    if (!summary) throw new Error("compaction returned no summary");
    const text = `This session continues from an earlier conversation that was compacted. Summary:\n\n${summary}`;
    this.messages = [{ role: "user", content: text }, { role: "assistant", content: [{ type: "text", text: "Understood; continuing from the summary." }] }];
    this.session?.compaction(text);
    this.session?.message(this.messages[1]);
    this.ctx.readFiles.clear();
    this.lastContext = reply.usage.output + 2000;
    this.ui.notice(`Compacted to ~${Math.round(summary.length / 4)} tokens.`);
  }

  // A read-only helper with its own context; returns its final answer.
  async subagent(brief) {
    const signal = this.ctx.signal;
    const tools = [
      ...READ_ONLY.filter((t) => t.name !== "skill"),
      {
        ...TOOLS.find((t) => t.name === "bash"),
        description: "Run a read-only shell command (ls, git status/diff/log, …). Anything that changes files is refused.",
      },
    ];
    const ctx = { ...this.ctx, readFiles: new Map(), ui: null };
    const messages = [{ role: "user", content: brief }];
    const system = `${this.system()}\n\n# You are a subagent\nYou research and report; you cannot change files. Finish with a complete, specific answer to the brief (paths with line numbers, findings, open questions). That answer is all the caller sees.`;
    for (let turn = 0; turn < 40; turn++) {
      const reply = await complete({ provider: this.provider, model: this.model, system, messages, tools, signal });
      this.track(reply.usage);
      messages.push({ role: "assistant", content: reply.content });
      const calls = reply.content.filter((p) => p.type === "toolCall");
      if (!calls.length) return reply.content.filter((p) => p.type === "text").map((p) => p.text).join("\n").trim() || "(no answer)";
      for (const call of calls) {
        const tool = tools.find((t) => t.name === call.name);
        let text;
        let isError = false;
        this.ui.subTool?.(call.name, call.arguments);
        try {
          if (!tool) throw new Error(`Unknown tool ${call.name}`);
          if (call.name === "bash" && !isSafeCommand(call.arguments?.command ?? "")) throw new Error("Only read-only commands are allowed in a subagent.");
          const out = await tool.run(call.arguments ?? {}, ctx);
          text = out.text;
          isError = out.isError;
        } catch (err) {
          if (signal?.aborted) throw signal.reason;
          text = `Error: ${err.message}`;
          isError = true;
        }
        messages.push({ role: "toolResult", toolCallId: call.id, toolName: call.name, content: [{ type: "text", text }], isError });
      }
    }
    return "(the subagent ran out of turns)";
  }
}
