# Agent hub

Run coding agents (Claude Code, omp, opencode, codex, pi, a shell or any
command) side by side, grouped by project, and see what they change.

Agents run in a dedicated tmux server (`tmux -L nvim-agents`), so they keep
running when Neovim exits or crashes.

## Requirements

- Neovim 0.11+ and `tmux` 3.2+
- Optional: `lazygit` (`g`), `terminal-browser` in WezTerm/Ghostty/kitty (`b`),
  `gh` (`P`), `python3` (hooks and the usage monitor)
- Agent CLIs: any of Claude Code, omp, pi, opencode, codex, hermes, or any
  command. Missing ones are simply not offered; nothing errors.

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
