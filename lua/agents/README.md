# Agent hub

Run coding agents (Claude Code, omp, opencode, codex, pi, a shell or any
command) side by side, grouped by project, and see what they change.

Agents run in a dedicated tmux server (`tmux -L nvim-agents`), so they keep
running when Neovim exits or crashes.

## Requirements

- Neovim 0.11+ and `tmux` 3.2+
- Optional: `lazygit` (`g`), `terminal-browser` in WezTerm/Ghostty/kitty (`b`),
  `python3` for the Claude hooks

## Setup

Once per machine, so Claude Code reports its status and activity to the hub:

```vim
:AgentsInstallHooks
```

This adds hooks that run `lua/agents/hooks/claude-state.sh` to
`~/.claude/settings.json` (a backup is saved as `settings.json.bak-agents`).
They apply to Claude sessions started afterwards. Remove them with
`:AgentsUninstallHooks`. Without the hooks the hub guesses Claude's status from
its screen, as it does for other tools.

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

Sidebar: `j`/`k` select, `⏎` focus, `1`-`9` focus tab N, `n` desk, `t` tab,
`r` rename, `x` kill, `R` restart, `D` diff, `O` office, `b` browser,
`g` lazygit, `Ctrl-Space` jump, `<Tab>` changes panel, `q` close.

Changes panel: `⏎` preview diff, `o` open file, `D` Diffview, `g` lazygit,
`r` refresh. In Diffview, `q` closes it and returns to the hub.

From an agent's terminal: `Ctrl-Space` jump, `<C-h>`/`<C-l>` move between
panels, `<C-esc>` normal mode.
