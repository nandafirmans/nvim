-- Context window use of Claude Code agents, read from the transcripts Claude
-- keeps in ~/.claude/projects/<cwd with non-alphanumerics as "-">/<id>.jsonl.
-- The last assistant message's usage is what the next turn sends, so it is
-- the current context size.
local M = {}

local TAIL_BYTES = 256 * 1024
local REFRESH_SECONDS = 10
-- Claude Code's default window. Sessions past it must be on the 1M window.
local DEFAULT_WINDOW = 200000
local LARGE_WINDOW = 1000000

local cache = {} -- agent name -> { at, info }

local function project_dir(cwd)
	return vim.fn.expand("~/.claude/projects/") .. cwd:gsub("[^%w]", "-")
end

-- The agent's transcript: by session id when the hook recorded one,
-- else the newest transcript in its folder written since the tab started.
local function transcript(agent)
	local dir = project_dir(agent.cwd)
	if agent.claude_session then
		local path = dir .. "/" .. agent.claude_session .. ".jsonl"
		if vim.uv.fs_stat(path) then
			return path
		end
	end
	local newest, newest_time
	for name, kind in vim.fs.dir(dir) do
		if kind == "file" and name:match("%.jsonl$") then
			local stat = vim.uv.fs_stat(dir .. "/" .. name)
			if stat and stat.mtime.sec >= agent.created and (not newest_time or stat.mtime.sec > newest_time) then
				newest, newest_time = dir .. "/" .. name, stat.mtime.sec
			end
		end
	end
	return newest
end

local function read_tail(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local size = file:seek("end")
	file:seek("set", math.max(0, size - TAIL_BYTES))
	local data = file:read("*a")
	file:close()
	return data
end

local function measure(agent)
	local path = transcript(agent)
	local data = path and read_tail(path)
	if not data then
		return nil
	end
	local lines = vim.split(data, "\n", { trimempty = true })
	for i = #lines, 1, -1 do
		local line = lines[i]
		if line:find('"usage"', 1, true) and line:find('"assistant"', 1, true) then
			local ok, entry = pcall(vim.json.decode, line)
			local usage = ok and type(entry) == "table" and type(entry.message) == "table" and entry.message.usage
			if type(usage) == "table" then
				local tokens = (usage.input_tokens or 0)
					+ (usage.cache_creation_input_tokens or 0)
					+ (usage.cache_read_input_tokens or 0)
					+ (usage.output_tokens or 0)
				local window = tokens > DEFAULT_WINDOW and LARGE_WINDOW or DEFAULT_WINDOW
				return { tokens = tokens, percent = math.floor(tokens * 100 / window + 0.5) }
			end
		end
	end
end

-- { tokens, percent } for a Claude agent, or nil. Cached for a few seconds.
function M.context(agent)
	if agent.tool ~= "claude" then
		return nil
	end
	local entry = cache[agent.name]
	if not entry or os.time() - entry.at >= REFRESH_SECONDS then
		entry = { at = os.time(), info = measure(agent) }
		cache[agent.name] = entry
	end
	return entry.info
end

function M.format(info)
	if info.tokens >= 1000 then
		return ("%dk %d%%"):format(math.floor(info.tokens / 1000 + 0.5), info.percent)
	end
	return ("%d %d%%"):format(info.tokens, info.percent)
end

function M.hl(info)
	if info.percent >= 80 then
		return "AgentsWaiting"
	elseif info.percent >= 60 then
		return "AgentsRunning"
	end
	return "AgentsDim"
end

return M
