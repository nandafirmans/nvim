// Reports opencode state to the Neovim agent hub (lua/agents), like the
// Claude Code hook does: status, task, current activity and the session id,
// as tmux options on the hub's session. Installed into
// ~/.config/opencode/plugins by :AgentsInstallHooks. Only agents started by
// the hub have NVIM_AGENT_SESSION; elsewhere this plugin does nothing.

import { execFile } from "node:child_process";
import path from "node:path";

const hubSession = process.env.NVIM_AGENT_SESSION;

function oneLine(text) {
  return String(text ?? "").split(/\s+/).filter(Boolean).join(" ").slice(0, 80);
}

function set(key, value) {
  execFile(
    "tmux",
    ["-L", "nvim-agents", "set-option", "-t", `=${hubSession}:`, `@agent_${key}`, oneLine(value)],
    () => {},
  );
}

function base(file) {
  return typeof file === "string" ? path.basename(file) : "";
}

// One short line saying what a tool call does, for the office bubble.
function describe(tool, args) {
  const name = String(tool ?? "").toLowerCase();
  const file = args?.filePath ?? args?.path ?? args?.file_path;
  if (["edit", "write", "patch", "multiedit"].includes(name)) return `Editing ${base(file)}`;
  if (name === "read") return `Reading ${base(file)}`;
  if (name === "bash") return `$ ${args?.description ?? args?.command ?? ""}`;
  if (["grep", "glob", "list", "codesearch"].includes(name)) return `Searching ${args?.pattern ?? args?.query ?? ""}`;
  if (name === "websearch") return `Googling ${args?.query ?? ""}`;
  if (name === "webfetch") return `Browsing ${args?.url ?? ""}`;
  if (name === "task") return `Delegating: ${args?.description ?? ""}`;
  if (name === "todowrite") return "Planning";
  return String(tool ?? "").replace(/_/g, " ");
}

function firstLine(text) {
  if (typeof text !== "string") return undefined;
  return text.split("\n").find((line) => line.trim()) ?? text;
}

export const NvimAgentsStatePlugin = async () => {
  if (!hubSession) {
    return {};
  }

  // Subagent (child) sessions report into their root; only the root counts.
  const children = new Set();
  let busy = false;
  const isChild = (sessionID) => sessionID && children.has(sessionID);

  set("status", "idle");
  set("activity", "");

  return {
    "chat.message": async (input, output) => {
      if (isChild(input?.sessionID)) return;
      if (input?.sessionID) set("session_id", input.sessionID);
      const parts = Array.isArray(output?.parts) ? output.parts : [];
      const text = parts.find((part) => part?.type === "text" && typeof part.text === "string");
      const task = firstLine(text?.text);
      if (task) set("task", task);
      busy = true;
      set("status", "running");
      set("activity", "Thinking…");
    },

    "tool.execute.before": async (input, output) => {
      if (isChild(input?.sessionID)) return;
      set("activity", describe(input?.tool, output?.args));
    },

    event: async ({ event }) => {
      const type = event?.type;
      const properties = event?.properties ?? {};
      const info = properties.info;
      if (info?.id && info.parentID) {
        children.add(info.id);
      }
      if (isChild(properties.sessionID)) return;

      switch (type) {
        case "session.status": {
          const kind = String(properties.status?.type ?? properties.status ?? "").toLowerCase();
          if (kind === "retry") {
            // Stuck on a provider error (rate or usage limit): needs a human.
            busy = true;
            set("status", "waiting");
            set("activity", properties.status?.message ?? "retrying after an error");
          } else if (kind && kind !== "idle") {
            busy = true;
            set("status", "running");
          }
          break;
        }
        case "permission.asked":
        case "permission.updated":
          set("status", "waiting");
          set("activity", properties.title ?? properties.permission ?? "approve tool");
          break;
        case "question.asked":
          set("status", "waiting");
          set("activity", properties.question ?? "needs you");
          break;
        case "permission.replied":
        case "question.replied":
        case "question.rejected":
          set("status", "running");
          break;
        case "session.error":
          set("status", "waiting");
          set("activity", "error: " + (properties.error?.data?.message ?? properties.error?.name ?? "see terminal"));
          break;
        case "session.idle":
          // Idle after a turn means done; idle with nothing asked stays idle.
          set("status", busy ? "done" : "idle");
          set("activity", "");
          busy = false;
          break;
        default:
          break;
      }
    },
  };
};
