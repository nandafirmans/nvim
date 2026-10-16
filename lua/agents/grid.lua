-- Mission control: every agent's screen at once, tiled in a grid. Each tile
-- is a live, coloured view of the agent (tmux capture-pane fed into a
-- terminal emulator buffer), so agents keep their own size. Entering a tile
-- types into that agent: keys go straight to its tmux pane. Ctrl-Space
-- leaves typing for the tile keys: o opens it full size in the hub,
-- p prompts, a approves, e sends Esc, R restarts.
local tmux = require("agents.tmux")

local M = {}

local MAX_TILES = 9
local REFRESH_MS = 700

local state = { tab = nil, tiles = {}, names = {}, timer = nil }

local function hub()
	return require("agents")._hub
end

local function valid_tab()
	return state.tab and vim.api.nvim_tabpage_is_valid(state.tab)
end

local function layout(n)
	if n <= 1 then
		return 1, 1
	elseif n == 2 then
		return 2, 1
	elseif n <= 4 then
		return 2, 2
	elseif n <= 6 then
		return 3, 2
	end
	return 3, 3
end

local STATUS_HL = {
	running = "AgentsRunning",
	waiting = "AgentsWaiting",
	done = "AgentsDone",
	idle = "AgentsIdle",
	exited = "AgentsExited",
}

local function winbar(tile, focused)
	local h = hub()
	local agent = h.S.by_name[tile.name]
	if not agent then
		return "%#AgentsDim#  (gone)"
	end
	local status = h.status_of(agent.name)
	local doing = agent.activity_text or h.S.tails[agent.name] or ""
	local function esc(text)
		return (tostring(text):gsub("%%", "%%%%"))
	end
	local mark = status == "waiting" and "%#AgentsWaiting# ! " or (focused and "%#AgentsBar# ▍" or "  ")
	local typing = focused and vim.api.nvim_get_mode().mode == "t"
	return table.concat({
		mark,
		typing and "%#AgentsJump# ⌨ typing %#AgentsTool# " or "",
		focused and "%#AgentsToolSel#" or "%#AgentsTool#",
		esc(h.display_name(agent)),
		"%#AgentsDim# · ",
		esc(agent.project),
		"  %#",
		STATUS_HL[status] or "AgentsDim",
		"#",
		status,
		"%#AgentsDim#  ",
		esc(doing),
		"%=",
	})
end

-- Cuts a line with ANSI colour codes to `width` visible cells, so it never
-- wraps (a wrapped line would scroll the tile and stack old frames).
local function clip(line, width)
	local out, used, i, n = {}, 0, 1, #line
	while i <= n do
		local c = line:sub(i, i)
		if c == "\27" then
			-- Copy the escape sequence whole: ESC [ params final-byte.
			local seq = line:match("^\27%[[%d;?]*[%a@`]", i) or line:match("^\27[^%[]", i) or c
			table.insert(out, seq)
			i = i + #seq
		else
			local len = c:byte() >= 0xF0 and 4 or c:byte() >= 0xE0 and 3 or c:byte() >= 0xC0 and 2 or 1
			local ch = line:sub(i, i + len - 1)
			local w = len == 1 and 1 or vim.fn.strdisplaywidth(ch)
			if used + w > width then
				break
			end
			table.insert(out, ch)
			used = used + w
			i = i + len
		end
	end
	return table.concat(out)
end

-- Bottom-aligned screen: drops trailing blank lines, keeps what fits.
local function fit_lines(text, height)
	local lines = vim.split(text, "\n", { plain = true })
	while #lines > 0 and vim.trim((lines[#lines]:gsub("\27%[[%d;]*m", ""))) == "" do
		table.remove(lines)
	end
	local first = math.max(1, #lines - height + 1)
	return vim.list_slice(lines, first, #lines)
end

local draw

-- Forwards what is typed in a tile to the agent, then redraws the tile soon
-- so typing feels live rather than waiting for the next refresh.
-- Keys are queued per tile and sent one batch at a time: separate tmux calls
-- run concurrently and could reorder keystrokes (Enter before the text).
local function flush(tile)
	if tile.sending or tile.pending == "" then
		return
	end
	local data = tile.pending
	tile.pending, tile.sending = "", true
	tmux.run({ "send-keys", "-t", "=" .. tile.name .. ":", "-l", data }, function()
		tile.sending = false
		flush(tile)
		draw(tile)
	end)
end

local function send_input(tile, data)
	tile.pending = (tile.pending or "") .. data
	flush(tile)
	vim.defer_fn(function()
		draw(tile)
	end, 150)
end

draw = function(tile)
	if not (vim.api.nvim_win_is_valid(tile.win) and vim.api.nvim_buf_is_valid(tile.buf)) then
		return
	end
	local height = vim.api.nvim_win_get_height(tile.win)
	local width = vim.api.nvim_win_get_width(tile.win)
	tmux.run({ "capture-pane", "-p", "-e", "-t", "=" .. tile.name .. ":" }, function(result)
		if not (vim.api.nvim_buf_is_valid(tile.buf) and vim.api.nvim_win_is_valid(tile.win)) then
			return
		end
		-- One row less than the tile, so the last line never scrolls it.
		local lines = result.code == 0 and fit_lines(result.stdout or "", height - 1) or { "  (no screen)" }
		local out = { "\27[H\27[2J" }
		for i, line in ipairs(lines) do
			table.insert(out, clip(line, width) .. "\27[0m\27[K" .. (i < #lines and "\r\n" or ""))
		end
		pcall(vim.api.nvim_chan_send, tile.chan, table.concat(out))
		-- Keep the view on the live screen, not on old scrollback.
		-- A tile being typed in follows its cursor already (and :normal is not
		-- allowed in terminal mode), so only the others are scrolled.
		vim.schedule(function()
			if not (vim.api.nvim_win_is_valid(tile.win) and vim.api.nvim_buf_is_valid(tile.buf)) then
				return
			end
			local typing = vim.api.nvim_get_current_win() == tile.win and vim.api.nvim_get_mode().mode == "t"
			if typing then
				return
			end
			pcall(vim.api.nvim_win_set_cursor, tile.win, { vim.api.nvim_buf_line_count(tile.buf), 0 })
			vim.api.nvim_win_call(tile.win, function()
				pcall(vim.cmd, "normal! zb")
			end)
		end)
	end)
end

local function refresh()
	if not valid_tab() then
		return M.stop()
	end
	local h = hub()
	-- Rebuild when tabs were added or killed.
	local names = {}
	for i, agent in ipairs(h.S.agents) do
		if i > MAX_TILES then
			break
		end
		table.insert(names, agent.name)
	end
	if table.concat(names, ",") ~= table.concat(state.names, ",") then
		M.build()
		return
	end
	local current = vim.api.nvim_get_current_win()
	for _, tile in ipairs(state.tiles) do
		if vim.api.nvim_win_is_valid(tile.win) then
			vim.wo[tile.win].winbar = winbar(tile, tile.win == current)
			-- A tile waiting for you gets a red separator around it.
			local waiting = h.status_of(tile.name) == "waiting"
			vim.wo[tile.win].winhighlight = waiting and "WinSeparator:AgentsWaiting,WinBar:AgentsWaitingBar,WinBarNC:AgentsWaitingBar"
				or "WinBar:AgentsPanel,WinBarNC:AgentsPanel"
			draw(tile)
		end
	end
end

local function tile_under_cursor()
	local win = vim.api.nvim_get_current_win()
	for _, tile in ipairs(state.tiles) do
		if tile.win == win then
			return tile
		end
	end
end

-- Runs a hub action on the tile's agent.
local function on_tile(fn)
	return function()
		local tile = tile_under_cursor()
		if not tile then
			return
		end
		hub().S.selected = tile.name
		fn(tile)
	end
end

local function open_full(tile)
	local h = hub()
	h.open()
	h.select_agent(tile.name, true)
end

local function map_tile(buf)
	local flow = require("agents.flow")
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
	end
	-- Back to typing into the agent.
	map("<CR>", vim.cmd.startinsert, "Type into this agent")
	map("i", vim.cmd.startinsert, "Type into this agent")
	map("o", on_tile(open_full), "Open this agent full size in the hub")
	map("<2-LeftMouse>", on_tile(open_full), "Open this agent full size in the hub")
	map("p", on_tile(flow.prompt), "Prompt this agent")
	map("a", on_tile(flow.approve), "Approve its permission prompt")
	map("e", on_tile(flow.deny), "Esc: decline or interrupt")
	map("R", on_tile(function(tile)
		require("agents").restart_agent(tile.name)
	end), "Restart (resume) this agent")
	map("x", on_tile(function(tile)
		require("agents").kill_agent(tile.name)
	end), "Remove this agent")
	map("q", M.close, "Close mission control")
	-- While typing: Ctrl-Space leaves typing, Ctrl-h/j/k/l move to the next tile.
	for _, lhs in ipairs({ "<C-Space>", "<C-@>" }) do
		vim.keymap.set("t", lhs, "<C-\\><C-n>", { buffer = buf, desc = "Stop typing (tile keys)" })
	end
	for _, dir in ipairs({ "h", "j", "k", "l" }) do
		vim.keymap.set("t", "<C-" .. dir .. ">", "<C-\\><C-n><C-w>" .. dir, { buffer = buf, desc = "Move to the next tile" })
	end
	map("?", function()
		vim.notify(
			"Typing goes to the agent. Ctrl-Space stops typing; then:\n"
				.. "⏎/i type again   o open full size   p prompt   a approve   e Esc   R restart   x remove   q close\n"
				.. "Ctrl-h/j/k/l or click moves between tiles",
			vim.log.levels.INFO,
			{ title = "Mission control" }
		)
	end, "Keys")
end

local function new_tile(win, name)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_win_set_buf(win, buf)
	local tile = { win = win, buf = buf, name = name, pending = "", sending = false }
	tile.chan = vim.api.nvim_open_term(buf, {
		on_input = function(_, _, _, data)
			send_input(tile, data)
		end,
	})
	-- Clicking or moving into a tile means typing into its agent.
	vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
		buffer = buf,
		callback = function()
			vim.schedule(function()
				if vim.api.nvim_get_current_buf() == buf then
					vim.cmd.startinsert()
				end
			end)
		end,
	})
	vim.bo[buf].filetype = "agentgrid"
	-- Frames replace each other; no history to scroll into.
	vim.bo[buf].scrollback = 1
	local wo = vim.wo[win]
	wo.number, wo.relativenumber, wo.signcolumn, wo.foldcolumn = false, false, "no", "0"
	wo.statuscolumn, wo.cursorline, wo.wrap, wo.spell = "", false, false, false
	map_tile(buf)
	return tile
end

-- (Re)creates the grid in the mission control tab.
function M.build()
	if not valid_tab() then
		return
	end
	local h = hub()
	vim.api.nvim_set_current_tabpage(state.tab)
	-- Start from one window.
	local wins = vim.api.nvim_tabpage_list_wins(state.tab)
	vim.api.nvim_set_current_win(wins[1])
	for i = 2, #wins do
		pcall(vim.api.nvim_win_close, wins[i], true)
	end
	local base = require("agents.canvas").fresh_window()

	state.tiles, state.names = {}, {}
	local agents = vim.list_slice(h.S.agents, 1, MAX_TILES)
	if #agents == 0 then
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
			"",
			"   No agents running.",
			"   Open the hub (<leader>mm) and press n to start one.",
		})
		vim.api.nvim_win_set_buf(base, buf)
		vim.keymap.set("n", "q", M.close, { buffer = buf })
		return
	end

	local cols, rows = layout(#agents)
	-- Rows first, then columns inside each row.
	local row_wins = { base }
	for _ = 2, rows do
		vim.api.nvim_set_current_win(row_wins[#row_wins])
		vim.cmd("belowright split")
		table.insert(row_wins, vim.api.nvim_get_current_win())
	end
	local slots = {}
	for _, row_win in ipairs(row_wins) do
		table.insert(slots, row_win)
		for _ = 2, cols do
			vim.api.nvim_set_current_win(slots[#slots])
			vim.cmd("belowright vsplit")
			table.insert(slots, vim.api.nvim_get_current_win())
		end
	end
	vim.cmd("wincmd =")

	for i, win in ipairs(slots) do
		local agent = agents[i]
		if agent then
			table.insert(state.tiles, new_tile(win, agent.name))
			table.insert(state.names, agent.name)
		else
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	if #h.S.agents > MAX_TILES then
		vim.notify(("Showing %d of %d agents"):format(MAX_TILES, #h.S.agents), vim.log.levels.INFO, { title = "Mission control" })
	end
	vim.api.nvim_set_current_win(state.tiles[1].win)
	refresh()
	vim.cmd.startinsert()
end

function M.stop()
	if state.timer then
		state.timer:stop()
		state.timer:close()
		state.timer = nil
	end
end

function M.close()
	M.stop()
	if valid_tab() then
		if #vim.api.nvim_list_tabpages() == 1 then
			vim.cmd("tabnew")
		end
		vim.cmd(vim.api.nvim_tabpage_get_number(state.tab) .. "tabclose")
	end
	state.tab, state.tiles, state.names = nil, {}, {}
end

function M.open()
	if not tmux.available() then
		vim.notify("Mission control needs tmux.", vim.log.levels.ERROR, { title = "Agents" })
		return
	end
	if valid_tab() then
		vim.api.nvim_set_current_tabpage(state.tab)
		return
	end
	vim.cmd("tabnew")
	state.tab = vim.api.nvim_get_current_tabpage()
	local h = hub()
	-- Make sure the agent list is current before tiling.
	h.poll(function()
		M.build()
		M.stop()
		state.timer = vim.uv.new_timer()
		state.timer:start(REFRESH_MS, REFRESH_MS, vim.schedule_wrap(refresh))
	end)
	vim.api.nvim_create_autocmd("TabClosed", {
		group = vim.api.nvim_create_augroup("AgentsGrid", { clear = true }),
		callback = function()
			if not valid_tab() then
				M.stop()
				state.tab, state.tiles, state.names = nil, {}, {}
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("AgentsGridResize", { clear = true }),
		callback = function()
			if valid_tab() and vim.api.nvim_get_current_tabpage() == state.tab then
				vim.cmd("wincmd =")
			end
		end,
	})
end

function M.toggle()
	if valid_tab() and vim.api.nvim_get_current_tabpage() == state.tab then
		M.close()
	else
		M.open()
	end
end

return M
