# Agent hub

Run coding agents (Claude Code, omp, opencode, codex, pi, a shell or any
command) side by side, grouped by project, and see what they change.

Agents run in a dedicated tmux server (`tmux -L nvim-agents`), so they keep
running when Neovim exits or crashes. A reboot or shutdown kills that server,
so the hub keeps a snapshot of its tabs (`stdpath("state")/agents/tabs.json`);
when it finds the server empty it starts them again, each agent resuming its
conversation and each terminal or command starting again in its folder.

## Requirements

- Neovim 0.11+ and `tmux` 3.2+
- Optional: `lazygit` (`g`), `terminal-browser` in WezTerm/Ghostty/kitty (`b`),
  `gh` (`P`), `python3` (hooks and the usage monitor)
- Agent CLIs: any of Claude Code, omp, pi, opencode, codex, hermes, the
  built-in wowo (needs Node 20+ and ripgrep), or any command. Missing ones are simply not offered; nothing errors.

## Setup

Once per machine, so each agent CLI reports its status, task, activity and
session id to the hub:

```vim
:AgentsInstallHooks            " every installed CLI
:AgentsInstallHooks omp codex  " only these
```

| CLI | What is installed |
| --- | --- |
| Claude Code | hooks in `~/.claude/settings.json` running `hooks/claude-state.sh` |
| omp, pi | extension link in `~/.omp/agent/extensions` / `~/.pi/agent/extensions` |
| opencode | plugin link in `~/.config/opencode/plugins` |
| codex | `notify` in `~/.codex/config.toml` (marks a turn done; left alone if you already use `notify`) |
| hermes | shell hooks in `~/.hermes/config.yaml` (hermes may ask once to allow them) |

Edited files get a `.bak-agents` backup. CLIs that are not installed are
skipped with a note. `:AgentsUninstallHooks` removes everything again. They
apply to agents started afterwards (`R` restarts a tab and resumes its
conversation). Without a hook, the hub guesses status from the screen.

## WOWO-AGENT: your own agent, your own keys

WOWO-AGENT (`wowo`) is the hub's own coding agent (`wowo-cli/`, Node 20+, no
dependencies), modelled on how Claude Code, omp and hermes work, and run
with your own keys. Any OpenAI-compatible endpoint (OmniRoute, 9router,
LiteLLM, OpenRouter, a local server) or Anthropic-compatible one works.

- **Loop**: streams the reply, runs tool calls, feeds results back until the
  model answers; retries rate limits and network errors with backoff.
- **Tools**: `read` (numbered lines, ranges), `write`, `edit` (exact match, must
  be unique, tolerant of indentation drift, shows a diff), `bash` (timeouts,
  output clipping, killed on Esc), `grep` and `glob` (ripgrep), `todo_write`,
  `web_fetch`, `task` (a read-only subagent with its own context) and `skill`.
  Files must be read before they are edited, and are re-read when they
  changed on disk.
- **Approval modes** (`⇧tab` cycles them; the line above the input shows the
  current one): **ask** asks before edits and commands (`y`, `a` always for
  that tool, `n`, `t` no with a reason, `⇧tab` switch to auto and go);
  **auto-edit** edits files without asking; **auto** runs everything without
  asking. Read-only commands such as `git status` never ask. Also `/mode`,
  `--edits`, `--auto`, or `permissions` in the config.
- **Context**: the system prompt carries the environment, the project's
  `AGENTS.md` / `CLAUDE.md` (repo root down to the folder), `~/.wowo/AGENTS.md`
  and the skills list. At 80% of the window the conversation is compacted
  into a handover summary (`/compact [focus]` by hand).
- **Sessions**: JSONL in `~/.wowo/agent/sessions`; `-c` continues the
  latest, `-r <id>` or `/resume` picks one. The hub resumes by session id on `R`.
- **Skills**: `~/.wowo/skills`, `~/.claude/skills`, `.claude/skills`; run as
  `/<name> [request]`, or the model loads them itself.
- **Print mode** for scripts and benchmark harnesses: `wowo -p "task"`
  (or input on stdin) runs to the end with every tool approved, prints the
  answer and exits non-zero on failure.
- **Hub**: reports status, task, activity and session id itself (no hook to
  install), so it works with the office, grid, Autopilot, handoff and the
  usage monitor. Multi-line prompts arrive whole (bracketed paste); text sent
  while it works waits for the next prompt.

```lua
require("agents").setup({
  wowo = {
    model = "omniroute/hermes-main",     -- default: the first model listed
    permissions = "ask",                 -- or "auto-edit", "auto" (⇧tab switches)
    instructions = "Answer in Indonesian.",
    providers = {
      omniroute = {
        base_url = "http://127.0.0.1:20128/v1",
        api_key = "OMNIROUTE_API_KEY",   -- env var name, or "!command" printing the key
        models = { "hermes-main", { id = "gpt-5.6", context = 400000, max_tokens = 64000 } },
      },
      anthropic = { base_url = "https://api.anthropic.com/v1", api = "anthropic", api_key = "ANTHROPIC_API_KEY", models = { "claude-sonnet-5-5" } },
    },
  },
})
```

The hub writes these to `~/.wowo/config.json` before each launch. Keys
are never written anywhere; a literal key in `api_key` is refused.
`:AgentsWowo check` calls each provider's `/models` and saves the list
for providers without `models`. Outside Neovim run `lua/agents/bin/wowo`.

Commands: `/model [n|name]`, `/models`, `/compact`, `/clear`, `/resume`,
`/cost`, `/mode`, `/skills`, `/todos`, `/help`, `/exit`. Without an argument
`/model`, `/resume` and `/mode` open a picker (`↑`/`↓`, type to filter, `⏎`).
Typing `/` shows matching commands and skills under the input, `@` matching
project files: `↑`/`↓` select, `Tab` completes, `⏎` runs the command (or
inserts the file), `Esc` hides the list. Keys: `⏎` sends,
`\⏎` or `Ctrl-J` new line, `⇧tab` approval mode, `Esc` interrupts, `Tab` completes, `↑`/`↓` history.

## From another device (phone, laptop)

The tabs are sessions on the hub's tmux server, so any terminal that reaches
this Mac can attach to them. Keep it inside a Tailscale tailnet; never expose
it with a public tunnel.

Nothing here is tied to one person's tailnet: each machine uses its own
Tailscale account, and the URLs come from `tailscale status` at run time.
Tailscale is optional; without it everything still works on the machine
itself.

1. On the Mac: install Tailscale (https://tailscale.com/download), log in with
   your account, and turn on System Settings → General → Sharing → Remote
   Login. Keep it awake while plugged in (Energy settings).
2. On the phone: Tailscale (same account) and an SSH app (Termius, Blink).
3. `ssh <user>@<your-mac>.<your-tailnet>.ts.net`, then `agents`.

`lua/agents/bin/agents` (linked as `~/.local/bin/agents`):

- `agents`: a menu of the tabs (status, tool); `⏎` attaches, `Ctrl-b d`
  comes back to the menu. Also opens the hub or a shell.
- `agents <name>` attaches one tab, `agents ls` lists them, `agents hub` opens
  Neovim with the hub.
- `agents web` serves a phone dashboard (`web/server.mjs`, `web/dashboard.html`,
  Node, no dependencies): one card per tab with its status, branch, what it is
  doing and its `+/-`, Approve / Deny / Stop / Prompt buttons, and a tap opens
  the tab's terminal (ttyd, behind the same login) with a row of Esc / Tab /
  Ctrl / arrow keys, swipe to scroll, tap to click and pinch to zoom. It asks
  for a PIN (set it on the Mac with `agents pin`; only a salted hash is
  stored, in `~/.local/state/agents/pin`), then keeps a login cookie for 30
  days; wrong PINs lock it for a minute, then longer. Everything listens on
  loopback; when Tailscale is installed and logged in, `tailscale serve`
  publishes it over HTTPS to the devices in your tailnet only and `agents web`
  prints the URL (otherwise it prints how to set Tailscale up).
  `AGENTS_WEB_PORT` (7681) and `AGENTS_WEB_HTTPS_PORT` (443) change the ports. It runs as a LaunchAgent (`local.agents.ttyd`), so it comes back after
  a restart; `agents web stop` removes it and turns the URL off. Safari's
  Share → Add to Home Screen makes it a full-screen app on an iPhone.

Below `compact_below` columns (120) the hub stacks the sidebar over the
changes panel in one narrow column, and switches back when the window
widens, so it is usable from a phone in landscape. Below `phone_below` (80)
the hub shows one panel at a time under a tab bar (`claude #1 │ Agents 5 │
Changes 2`): tap a tab, or move into a panel, to switch. Picking a tab
opens the agent ready for typing.

## Keys

Global:

| Key | Action |
| --- | --- |
| `<leader>mm` | toggle the hub (`:Agents`) |
| `<leader>mn` | new desk: project, agent, optional worktree branch |
| `<leader>mt` | new tab in the selected desk |
| `<leader>mo` | Agent Office view |
| `<leader>mj` | jump to a tab |
| `<leader>ms` | send the file (or selected lines) to the selected agent |
| `<leader>md` | Diffview of the selected agent's changes |
| `<leader>mg` | lazygit in the selected agent's repo |
| `<leader>mb` | open or close terminal-browser |
| `<leader>mp` | type a prompt to the selected agent |
| `<leader>mf` | find a tab (fuzzy) |
| `<leader>mF` | fan out one prompt to several worktrees |
| `<leader>mq` | autopilot prompt queue (`:AgentsQueue`, `:AgentsQueueStop`) |
| `<leader>mh` | hand off the selected agent to another CLI (`:AgentsHandoff`) |
| `<leader>mc` | mission control: every agent's screen in a grid (`:AgentsGrid`) |
| `<leader>ma` | usage monitor for every agent CLI (`:AgentsMonitor`) |

Sidebar: `j`/`k` select, `⏎` focus, `1`-`9` focus tab N, `n` desk, `t` tab,
`p` prompt, `a` approve a permission prompt, `e` Esc (decline or interrupt),
`F` fan out, `f` find, `r` rename, `x` kill, `R` restart (Claude resumes its
conversation), `P` push and open a PR, `M` merge the worktree branch,
`W` remove the worktree, `D` diff, `O` office, `b` browser, `g` lazygit,
`A` usage monitor, `Ctrl-Space` jump, `<Tab>` changes panel, `?` all keys,
`q` close.

Changes panel: `⏎` preview diff, `o` open file, `D` Diffview, `g` lazygit,
`S` send review comments, `r` refresh. In the diff preview, `c` comments on
the line under the cursor and `S` sends all comments to the agent as one
prompt. In Diffview, `q` closes it and returns to the hub.

An agent started in a folder that is not a repository but holds several
(`attendance/` with `attendance-web/` and `attendance-api/`) gets one group
per repository in the changes panel, each with its branch and `+/-`; the
keys act on the repository of the file under the cursor.

## Workflow

- **Fan out** (`F`): one prompt goes to N agents, each in its own worktree
  and branch (`<prefix>-1..N`). Compare them in the changes panel, `M` merge
  the best one, `W` remove the others.
- **Context**: Claude tabs show their context window use (from the
  transcripts in `~/.claude/projects`); above 80% the office suggests
  `/compact`.
- **Office prompts** (`<leader>mo`, `O`): `h`/`j`/`k`/`l` walk between
  cubicles and desk labels. `p` prompts what is under the cursor: an agent, or
  a whole desk (every seat in that folder). In the prompt box `Tab` switches
  the recipient: the agent, the whole desk, its free seats, another seat, or a
  new agent at the desk started with the prompt. A sent prompt shows in the
  agent's bubble while an envelope drops onto its monitor.
- **Notifications**: when an agent finishes or needs input while Neovim is not
  focused, macOS shows a notification.
- **Mission control** (`<leader>mc`, `G`): every agent's live screen in a grid
  (up to 9). Entering a tile types into that agent; `Ctrl-Space` stops typing,
  then `o` opens it full size, `p` prompts, `a` approves, `R` restarts. A tile
  that needs you turns red.
- **Autopilot** (`Q`, `<leader>mq`): a queue of prompts per agent, listed by
  folder. `a` adds one, `A` adds several (one per line), `s` starts or stops,
  `S` stops all, `K`/`J` reorder, `e` edits, `d` deletes, `x` clears finished.
  The next prompt goes out when the agent finishes the previous one; the
  queue pauses by itself when the agent needs input, hits a limit, exits or
  does not pick a prompt up. Queues survive a Neovim restart.
- **Handoff** (`H`, automatic on usage limits): continues an agent's work in
  another CLI (claude ↔ omp by default) with a brief of the task, recent
  requests, last report and changed files. When both are limited it stops.
- **Usage monitor** (`<leader>ma`, `A`): sessions, prompts, tool calls,
  input/output/cache tokens, cost (where the CLI records it), tokens per day,
  top projects and models, for today / 7 days / 30 days, plus what is live in
  the hub. Read-only, from each CLI's own files; agents that are not installed
  or unused show a note instead of numbers.

From an agent's terminal: `Ctrl-Space` jump, `<C-h>`/`<C-l>` move between
panels, `<C-esc>` normal mode.
