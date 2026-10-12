-- Day-to-day agent workflow on top of the hub: talk to an agent without
-- entering its terminal, fan one prompt out to several worktrees, ship a
-- worktree (PR, merge, remove), resume Claude, find a tab, and macOS
-- notifications. `hub` is the internal API that agents/init.lua passes in.
local tmux = require("agents.tmux")

local M = {}

local hub

function M.setup(api)
	hub = api
end

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Agents" })
end

local function git(cwd, args)
	local ok, job = pcall(vim.system, vim.list_extend({ "git", "-C", cwd }, args), { text = true })
	if not ok then
		return false, "", "git is not installed"
	end
	local result = job:wait()
	return result.code == 0, vim.trim(result.stdout or ""), vim.trim(result.stderr or "")
end

-- How each agent CLI resumes its conversation in the same folder and takes
-- a first prompt on the command line (from their --help).
local q = vim.fn.shellescape
local TOOLS = {
	claude = {
		resume = function(base, agent)
			if agent.claude_session then
				return base .. " --resume " .. q(agent.claude_session)
			end
			return base .. " --continue"
		end,
		prompt = function(base, text)
			return base .. " " .. q(text)
		end,
	},
	omp = {
		-- The extension records the session id; without it, the latest here.
		resume = function(base, agent)
			if agent.session_id then
				return base .. " --resume " .. q(agent.session_id)
			end
			return base .. " --continue"
		end,
		prompt = function(base, text)
			return base .. " " .. q(text)
		end,
	},
	pi = {
		resume = function(base)
			return base .. " --continue"
		end,
		prompt = function(base, text)
			return base .. " " .. q(text)
		end,
	},
	opencode = {
		-- The plugin records the session id; without it, the latest here.
		resume = function(base, agent)
			if agent.session_id then
				return base .. " --session " .. q(agent.session_id)
			end
			return base .. " --continue"
		end,
		prompt = function(base, text)
			return base .. " --prompt " .. q(text)
		end,
	},
	codex = {
		-- notify records the thread id after the first turn.
		resume = function(base, agent)
			if agent.session_id then
				return base .. " resume " .. q(agent.session_id)
			end
			return base .. " resume --last"
		end,
		prompt = function(base, text)
			return base .. " " .. q(text)
		end,
	},
	hermes = {
		-- The hook records the session id; "latest" is this workspace's newest.
		resume = function(base, agent)
			return base .. " --resume " .. (agent.session_id and q(agent.session_id) or "latest")
		end,
		prompt = function(base, text)
			return base .. " chat -q " .. q(text)
		end,
	},
}

-- `base` started with `text` as its first prompt, for CLIs that take one.
function M.first_prompt_command(tool, base, text)
	local spec = TOOLS[tool]
	return spec and spec.prompt(base, text) or base
end

-- 1. Talk to an agent ------------------------------------------------------------

-- Types text into the agent's prompt and submits it.
function M.submit(name, text)
	tmux.paste(name, text, function()
		-- Give the TUI a moment to take the paste before Enter submits it.
		vim.defer_fn(function()
			tmux.send_keys(name, "Enter")
		end, 120)
	end)
end

function M.prompt()
	local agent = hub.selected_agent()
	if not agent then
		return
	end
	require("agents.prompt_box").open(agent, "Prompt for " .. hub.agent_label(agent), function(text)
		M.submit(agent.name, text)
	end)
end

-- Accepts the highlighted choice of a permission prompt (Claude: "Yes").
function M.approve()
	local agent = hub.selected_agent()
	if not agent then
		return
	end
	if hub.status_of(agent.name) ~= "waiting" then
		notify(hub.agent_label(agent) .. " is not asking for anything", vim.log.levels.WARN)
		return
	end
	tmux.send_keys(agent.name, "Enter")
end

-- Escape: declines a permission prompt, or interrupts a running agent.
function M.deny()
	local agent = hub.selected_agent()
	if agent then
		tmux.send_keys(agent.name, "Escape")
	end
end

-- 2. Fan out -----------------------------------------------------------------------

local function main_root(cwd)
	local ok, common = git(cwd, { "rev-parse", "--path-format=absolute", "--git-common-dir" })
	if not ok then
		return nil
	end
	return vim.fs.dirname(common)
end

-- Same prompt to several agents, each in its own worktree and branch, to
-- compare the results and keep the best.
function M.fanout()
	local agent = hub.selected_agent()
	local function with_root(root)
		hub.choose_command(false, function(tool, command)
			vim.ui.input({ prompt = "Prompt for every agent: " }, function(prompt)
				if not prompt or vim.trim(prompt) == "" then
					return
				end
				vim.ui.input({ prompt = "How many agents: ", default = "3" }, function(count)
					count = tonumber(count)
					if not count or count < 1 or count > 8 then
						return
					end
					local words = prompt:lower():gsub("[^%w%s]", ""):gsub("%s+", "-"):sub(1, 24):gsub("%-$", "")
					vim.ui.input({ prompt = "Branch prefix: ", default = "try/" .. words }, function(prefix)
						if not prefix or vim.trim(prefix) == "" then
							return
						end
						M.launch(root, tool, command, vim.trim(prompt), count, vim.trim(prefix))
					end)
				end)
			end)
		end)
	end
	if agent then
		local root = main_root(agent.cwd)
		if root then
			with_root(root)
			return
		end
	end
	hub.pick(hub.find_projects(), {
		prompt = "Project",
		format = function(path)
			return vim.fn.fnamemodify(path, ":~")
		end,
	}, with_root)
end

function M.launch(root, tool, command, prompt, count, prefix)
	local git_mod = require("agents.git")
	local started = {}
	for i = 1, count do
		local branch = prefix .. "-" .. i
		local cwd, err = git_mod.add_worktree(root, branch)
		if not cwd then
			notify("git worktree add " .. branch .. " failed: " .. err, vim.log.levels.ERROR)
			break
		end
		-- Known CLIs take the first prompt as an argument; others get it typed in.
		local spec = TOOLS[tool]
		local cmd = spec and spec.prompt(command, prompt) or command
		local name = hub.create_agent({
			project = vim.fs.basename(root),
			cwd = cwd,
			tool = tool,
			command = cmd,
			branch = branch,
			label = vim.fs.basename(branch),
			focus = false,
		})
		if name then
			table.insert(started, name)
		end
	end
	if not TOOLS[tool] then
		vim.defer_fn(function()
			for _, name in ipairs(started) do
				M.submit(name, prompt)
			end
		end, 5000)
	end
	notify(("Started %d agents on %s-1..%d. Compare them in the changes panel."):format(#started, prefix, #started))
end

-- 4. Ship a worktree -------------------------------------------------------------

-- Runs a shell command in a float that stays open, so output and prompts
-- (gh auth, merge conflicts) are visible.
local function run_float(cmd, cwd, on_exit)
	local ok, toggleterm = pcall(require, "toggleterm.terminal")
	if not ok then
		notify("toggleterm.nvim is needed for this", vim.log.levels.ERROR)
		return
	end
	toggleterm.Terminal
		:new({
			cmd = cmd .. "; echo; echo '[press q to close]'",
			dir = cwd,
			direction = "float",
			close_on_exit = false,
			hidden = true,
			on_open = function(term)
				vim.keymap.set("n", "q", function()
					term:shutdown()
				end, { buffer = term.bufnr, nowait = true })
			end,
			on_exit = function()
				vim.schedule(function()
					hub.refresh_changes()
					if on_exit then
						on_exit()
					end
				end)
			end,
		})
		:toggle()
end

local function shippable()
	local agent = hub.selected_agent()
	if not agent then
		return nil
	end
	local _, branch = git(agent.cwd, { "rev-parse", "--abbrev-ref", "HEAD" })
	return agent, branch
end

-- Pushes the agent's branch and opens a pull request (gh pr create --fill).
function M.pull_request()
	local agent, branch = shippable()
	if not agent then
		return
	end
	if branch == "" or branch == "HEAD" or branch == "main" or branch == "master" then
		notify("Agent is on " .. (branch ~= "" and branch or "no branch") .. "; work on a branch (n with a worktree) to open a PR", vim.log.levels.WARN)
		return
	end
	if vim.fn.executable("gh") == 0 then
		notify("gh (GitHub CLI) is not installed", vim.log.levels.ERROR)
		return
	end
	local _, dirty = git(agent.cwd, { "status", "--porcelain" })
	if dirty ~= "" then
		notify("Uncommitted changes in " .. branch .. " are not in the PR; commit them first (g lazygit)", vim.log.levels.WARN)
	end
	run_float("git push -u origin HEAD && gh pr create --fill --head " .. vim.fn.shellescape(branch), agent.cwd)
end

-- Merges the agent's worktree branch into the branch checked out in the main repo.
function M.merge()
	local agent, branch = shippable()
	if not agent then
		return
	end
	local root = main_root(agent.cwd)
	if not root or vim.fs.normalize(root) == vim.fs.normalize(agent.cwd) then
		notify("Merge works on agents in a worktree; this agent works in the repo itself", vim.log.levels.WARN)
		return
	end
	local _, dirty = git(agent.cwd, { "status", "--porcelain" })
	if dirty ~= "" then
		notify(branch .. " has uncommitted changes; commit them first (g lazygit, or ask the agent)", vim.log.levels.WARN)
		return
	end
	local _, base = git(root, { "rev-parse", "--abbrev-ref", "HEAD" })
	if vim.fn.confirm(("Merge %s into %s?"):format(branch, base), "&Merge\n&Cancel", 2) ~= 1 then
		return
	end
	run_float("git merge --no-ff " .. vim.fn.shellescape(branch), root)
end

-- Removes the agent's worktree (and, if merged, its branch) and ends its tabs.
function M.remove_worktree()
	local agent, branch = shippable()
	if not agent then
		return
	end
	local root = main_root(agent.cwd)
	if not root or vim.fs.normalize(root) == vim.fs.normalize(agent.cwd) then
		notify("This agent works in the repo itself, not in a worktree", vim.log.levels.WARN)
		return
	end
	local prompt = ("Remove worktree %s and kill its tabs?"):format(vim.fn.fnamemodify(agent.cwd, ":~"))
	if vim.fn.confirm(prompt, "&Remove\n&Cancel", 2) ~= 1 then
		return
	end
	-- `git worktree remove` refuses when there are uncommitted changes; keep it that way.
	local ok, _, err = git(root, { "worktree", "remove", agent.cwd })
	if not ok then
		notify("git worktree remove failed: " .. err, vim.log.levels.ERROR)
		return
	end
	for _, tab in ipairs(hub.S.agents) do
		if tab.cwd == agent.cwd then
			tmux.kill(tab.name)
		end
	end
	if vim.fn.confirm("Also delete branch " .. branch .. "? (only if merged)", "&Delete\n&Keep", 2) == 1 then
		local deleted, _, derr = git(root, { "branch", "-d", branch })
		if not deleted then
			notify("Kept " .. branch .. ": " .. derr, vim.log.levels.WARN)
		end
	end
	hub.poll(hub.refresh_changes)
end

-- 7. Resume ----------------------------------------------------------------------

-- The command a restart runs: known CLIs resume their conversation in this
-- folder (Claude by the session id its hook recorded); anything else (a
-- shell, a dev server) runs its original command again.
function M.restart_command(agent)
	local command = agent.command or agent.tool
	local spec = TOOLS[agent.tool]
	if spec then
		return spec.resume(command:match("^(%S+)") or agent.tool, agent)
	end
	return command
end

-- 9. Find ------------------------------------------------------------------------

function M.find()
	if #hub.S.agents == 0 then
		notify("No agents running")
		return
	end
	hub.pick(hub.S.agents, {
		prompt = "Agents",
		format = function(agent)
			local status = hub.status_of(agent.name)
			local doing = agent.activity_text or hub.S.tails[agent.name] or agent.task or ""
			return ("%-11s %s · %s  %s"):format(status, agent.project, hub.display_name(agent), doing)
		end,
	}, function(agent)
		hub.open()
		hub.select_agent(agent.name, true)
	end)
end

-- 3. macOS notifications ---------------------------------------------------------

local focused = true

function M.track_focus(group)
	vim.api.nvim_create_autocmd("FocusLost", {
		group = group,
		callback = function()
			focused = false
		end,
	})
	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			focused = true
		end,
	})
end

-- Shows a system notification when Neovim's window is not focused.
function M.system_notify(title, message)
	if focused or vim.fn.has("mac") == 0 then
		return
	end
	local function quote(text)
		return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
	end
	pcall(vim.system, {
		"osascript",
		"-e",
		("display notification %s with title %s sound name \"Glass\""):format(quote(message), quote(title)),
	})
end

return M
