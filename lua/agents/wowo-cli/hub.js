// Reports state to the Neovim agent hub (lua/agents): status, task, activity
// and session id as tmux options on the hub's session, like the hooks for
// Claude Code and omp do. Only tabs the hub started have NVIM_AGENT_SESSION.
import { execFile } from "node:child_process";

const session = process.env.NVIM_AGENT_SESSION;
const socket = process.env.NVIM_AGENT_SOCKET || "nvim-agents";

function oneLine(text) {
  return String(text ?? "").split(/\s+/).filter(Boolean).join(" ").slice(0, 80);
}

export function report(key, value) {
  if (!session) return;
  execFile("tmux", ["-L", socket, "set-option", "-t", `=${session}:`, `@agent_${key}`, oneLine(value)], () => {});
}

export function status(value, activity) {
  report("status", value);
  if (activity !== undefined) report("activity", activity);
}

// One short line saying what a tool call does, for the office bubble.
export function describe(name, args = {}) {
  const base = (p) => String(p ?? "").split("/").pop();
  switch (name) {
    case "edit":
    case "write":
      return `Editing ${base(args.path)}`;
    case "read":
      return `Reading ${base(args.path)}`;
    case "bash":
      return `$ ${args.description ?? args.command ?? ""}`;
    case "grep":
    case "glob":
      return `Searching ${args.pattern ?? ""}`;
    case "web_fetch":
      return `Browsing ${args.url ?? ""}`;
    case "task":
      return `Delegating: ${args.description ?? ""}`;
    case "todo_write":
      return "Planning";
    default:
      return name;
  }
}
