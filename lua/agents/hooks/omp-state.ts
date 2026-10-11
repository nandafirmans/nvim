// Reports omp state to the Neovim agent hub (lua/agents), like the Claude
// Code hook does: status, task, current activity and the session id, as tmux
// options on the hub's session. Installed into ~/.omp/agent/extensions by
// :AgentsInstallHooks. Only agents started by the hub have NVIM_AGENT_SESSION;
// elsewhere this extension does nothing.
// @ts-nocheck

import { execFile } from "node:child_process";
import path from "node:path";

const hubSession = process.env.NVIM_AGENT_SESSION;

function set(key: string, value: string | undefined) {
  execFile(
    "tmux",
    ["-L", "nvim-agents", "set-option", "-t", `=${hubSession}:`, `@agent_${key}`, oneLine(value ?? "")],
    () => {},
  );
}

function oneLine(text: string): string {
  return String(text).split(/\s+/).filter(Boolean).join(" ").slice(0, 80);
}

function base(file: unknown): string {
  return typeof file === "string" ? path.basename(file) : "";
}

// One short line saying what a tool call does, for the office bubble.
function describe(toolName: string, args: any): string {
  const name = String(toolName || "").toLowerCase();
  const file = args?.path ?? args?.file_path ?? args?.file ?? args?.filePath;
  if (["edit", "write", "multiedit", "patch", "apply_patch"].includes(name)) return `Editing ${base(file)}`;
  if (name === "read") return `Reading ${base(file)}`;
  if (["bash", "shell", "exec"].includes(name)) return `$ ${args?.description ?? args?.command ?? ""}`;
  if (["grep", "find", "glob", "search", "ast_grep"].includes(name)) return `Searching ${args?.pattern ?? args?.query ?? ""}`;
  if (["web_search", "websearch"].includes(name)) return `Googling ${args?.query ?? ""}`;
  if (["fetch", "web_fetch", "browser"].includes(name)) return `Browsing ${args?.url ?? ""}`;
  if (["task", "agent", "subagent"].includes(name)) return `Delegating: ${args?.description ?? args?.prompt ?? ""}`;
  if (name === "todo" || name === "todo_write") return "Planning";
  return String(toolName || "").replace(/_/g, " ");
}

// The prompt that started this turn, when the event carries it.
function promptOf(event: any): string | undefined {
  if (typeof event?.prompt === "string") return event.prompt;
  const messages = Array.isArray(event?.messages) ? event.messages : [];
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const message = messages[i];
    if (message?.role !== "user") continue;
    if (typeof message.content === "string") return message.content;
    const part = Array.isArray(message.content) ? message.content.find((p: any) => typeof p?.text === "string") : undefined;
    if (part) return part.text;
  }
  return undefined;
}

export default function (pi) {
  if (!hubSession) {
    return;
  }

  // Subagents run in the same process without a UI; report only the main session.
  const isMain = (ctx: any) => ctx?.hasUI !== false;

  pi.on("session_start", (_event, ctx) => {
    if (!isMain(ctx)) return;
    set("status", "idle");
    set("activity", "");
    const id = ctx?.sessionManager?.getSessionId?.();
    if (id) set("session_id", id);
  });

  pi.on("agent_start", (event, ctx) => {
    if (!isMain(ctx)) return;
    set("status", "running");
    set("activity", "Thinking…");
    const prompt = promptOf(event);
    if (prompt) set("task", prompt.split("\n").find((line) => line.trim()) ?? prompt);
  });

  // The prompt text arrives on the input events, not on agent_start.
  const setTask = (text: unknown) => {
    if (typeof text !== "string" || !text.trim()) return;
    set("task", text.split("\n").find((line) => line.trim()) ?? text);
  };
  pi.on("input", (event, ctx) => {
    if (!isMain(ctx)) return;
    setTask(event?.text ?? event?.prompt ?? event?.input);
  });
  pi.on("before_agent_start", (event, ctx) => {
    if (!isMain(ctx)) return;
    setTask(event?.prompt ?? event?.text);
  });

  pi.on("tool_execution_start", (event, ctx) => {
    if (!isMain(ctx)) return;
    if (event?.toolName === "ask") {
      const question = event?.args?.questions?.find?.((q: any) => typeof q?.question === "string");
      set("status", "waiting");
      set("activity", question?.question ?? "needs you");
      return;
    }
    set("activity", describe(event?.toolName, event?.args));
  });

  pi.on("tool_execution_end", (event, ctx) => {
    if (!isMain(ctx)) return;
    if (event?.toolName === "ask") set("status", "running");
  });

  pi.on("tool_approval_requested", (event, ctx) => {
    if (!isMain(ctx)) return;
    set("status", "waiting");
    set("activity", event?.reason || `approve ${event?.toolName ?? "tool"}`);
  });

  pi.on("tool_approval_resolved", (_event, ctx) => {
    if (!isMain(ctx)) return;
    set("status", "running");
  });

  pi.on("agent_end", (event, ctx) => {
    if (!isMain(ctx)) return;
    // A scheduled continuation is not the end of the turn.
    if (event?.willContinue === true) return;
    set("status", "done");
    set("activity", "");
  });
}
