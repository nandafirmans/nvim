-- wowo: the hub's own coding agent, bring-your-own-key. The agent itself
-- is lua/agents/wowo-cli (Node, no dependencies): its own loop, tools,
-- approvals, sessions, compaction, subagents and skills. This module writes
-- its settings, ~/.wowo/config.json, from the providers you configure:
-- any OpenAI- or Anthropic-compatible endpoint such as OmniRoute, 9router, a
-- local server or a provider's API.
--
--   require("agents").setup({ wowo = {
--     model = "omniroute/hermes-main",
--     providers = {
--       omniroute = {
--         base_url = "http://127.0.0.1:20128/v1",
--         api_key = "OMNIROUTE_API_KEY",            -- env var name, or
--         -- api_key = "!security find-generic-password -s omniroute -w",
--         models = { "hermes-main", { id = "gpt-5.6", context = 400000 } },
--       },
--     },
--   } })
--
-- Keys are never written anywhere: api_key names an environment variable or
-- a "!command" that prints the key, resolved by wowo when it sends a
-- request. A provider without `models` uses the list fetched by
-- :AgentsWowo check.
local M = {}

local config = {
	home = "~/.wowo",
	model = nil,
	instructions = nil,
	-- Approvals: "ask" (edits and commands), "auto-edit" (ask for commands only),
	-- "auto" (never ask). Shift-Tab in wowo switches while it runs.
	permissions = "ask",
	providers = {},
}

local function home()
	return vim.fs.normalize(vim.fn.expand(config.home))
end

function M.agent_dir()
	return home() .. "/agent"
end

local function script()
	local src = debug.getinfo(1, "S").source:sub(2)
	return vim.fs.dirname(src) .. "/bin/wowo"
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "WOWO-AGENT" })
end

-- Providers --------------------------------------------------------------------

-- A key written into the config instead of an env var name or a command.
local function looks_literal(key)
	return type(key) == "string" and not key:match("^!") and not key:match("^[%u_][%u%d_]*$")
end

local function discovered_path()
	return home() .. "/discovered.json"
end

local function read_json(path)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end
	local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	return decoded_ok and data or nil
end

local function write_file(path, text)
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local file = io.open(path, "w")
	if not file then
		return false
	end
	file:write(text)
	file:close()
	return true
end

-- Models of a provider: from the config, else from the last check.
local function models_of(name, provider)
	if type(provider.models) == "table" and #provider.models > 0 then
		return provider.models
	end
	local found = read_json(discovered_path()) or {}
	return found[name] or {}
end

-- "provider/model" for every configured model, the default one first.
function M.models()
	local out = {}
	local names = vim.tbl_keys(config.providers)
	table.sort(names)
	for _, name in ipairs(names) do
		for _, m in ipairs(models_of(name, config.providers[name])) do
			table.insert(out, name .. "/" .. (type(m) == "table" and m.id or m))
		end
	end
	if config.model then
		for i, id in ipairs(out) do
			if id == config.model then
				table.remove(out, i)
				break
			end
		end
		table.insert(out, 1, config.model)
	end
	return out
end

function M.default_model()
	return M.models()[1]
end

-- "openai" or "anthropic"; omp-style names are accepted too.
local function api_of(provider)
	return (provider.api or "openai"):find("anthropic") and "anthropic" or "openai"
end
-- Problems with the config, as lines for the user.
local function problems()
	local out = {}
	if vim.fn.executable("node") == 0 then
		table.insert(out, "node is not installed (wowo runs on Node)")
	end
	if vim.tbl_isempty(config.providers) then
		table.insert(out, "no providers: set wowo.providers in require('agents').setup()")
	end
	for name, p in pairs(config.providers) do
		if not p.base_url then
			table.insert(out, name .. ": base_url is missing")
		end
		if not p.api_key then
			table.insert(out, name .. ": api_key is missing (an env var name or a !command)")
		elseif looks_literal(p.api_key) then
			table.insert(out, name .. ": api_key looks like a literal key; use an env var name or a !command")
		end
		if #models_of(name, p) == 0 then
			table.insert(out, name .. ": no models; list them or run :AgentsWowo check")
		end
	end
	return out
end

-- Writes ~/.wowo/config.json from the config. Run before every launch,
-- so changes take effect on the next tab. Returns false when it cannot run.
function M.prepare()
	local fatal = vim.tbl_filter(function(line)
		return line:find("not installed") or line:find("no providers") or line:find("literal key")
	end, problems())
	if #fatal > 0 then
		notify(table.concat(fatal, "\n"), vim.log.levels.ERROR)
		return false
	end
	-- The agent used to be called doagent; carry its home (sessions,
	-- discovered models) over once.
	local old = vim.fn.expand("~/.doagent")
	if home() == vim.fs.normalize(vim.fn.expand("~/.wowo")) and vim.fn.isdirectory(home()) == 0 and vim.fn.isdirectory(old) == 1 then
		vim.fn.rename(old, home())
	end
	local providers = {}
	for name, p in pairs(config.providers) do
		if p.base_url and p.api_key then
			providers[name] = {
				base_url = p.base_url,
				api = api_of(p),
				api_key = p.api_key,
				headers = p.headers,
				context = p.context,
				max_tokens = p.max_tokens,
				models = models_of(name, p),
			}
		end
	end
	local settings = {
		model = M.default_model(),
		instructions = config.instructions,
		permissions = config.permissions,
		providers = providers,
	}
	return write_file(home() .. "/config.json", vim.json.encode(settings) .. "\n")
end

-- Hub ------------------------------------------------------------------------------

function M.available()
	return vim.fn.executable("node") == 1 and not vim.tbl_isempty(config.providers)
end

-- The command a hub tab runs; `model` picks one other than the default.
function M.command(model)
	local cmd = vim.fn.shellescape(script())
	if home() ~= vim.fs.normalize(vim.fn.expand("~/.wowo")) then
		cmd = cmd .. " --home " .. vim.fn.shellescape(home())
	end
	if model and model ~= M.default_model() then
		cmd = cmd .. " --model " .. vim.fn.shellescape(model)
	end
	return cmd
end

-- Asks which model when there are several; cb(command) or nothing on cancel.
function M.choose(pick, cb)
	if not M.prepare() then
		return
	end
	local models = M.models()
	if #models == 0 then
		-- Nothing listed: ask the providers once, then try again.
		return M.check(function()
			if #M.models() == 0 then
				notify("No models: list them in wowo.providers", vim.log.levels.WARN)
				return
			end
			M.choose(pick, cb)
		end)
	end
	if #models == 1 then
		return cb(M.command())
	end
	pick(models, {
		prompt = "wowo model",
		format = function(id)
			return id == models[1] and (id .. "  (default)") or id
		end,
	}, function(model)
		if model then
			cb(M.command(model))
		end
	end)
end

-- Check ------------------------------------------------------------------------

-- Resolves an api_key setting the way wowo does, only to call the provider
-- from :AgentsWowo check. The key goes to curl on stdin, never argv.
local function resolve_key(spec)
	if type(spec) ~= "string" then
		return nil
	end
	if spec:sub(1, 1) == "!" then
		local ok, job = pcall(vim.system, { "/bin/sh", "-c", spec:sub(2) }, { text = true })
		if not ok then
			return nil
		end
		local result = job:wait(10000)
		return result.code == 0 and vim.trim(result.stdout or "") or nil
	end
	local value = vim.env[spec]
	return value ~= "" and value or nil
end

local function fetch_models(provider, cb)
	local key = resolve_key(provider.api_key)
	if not key then
		return cb(nil, "key not found (" .. tostring(provider.api_key) .. ")")
	end
	local url = provider.base_url:gsub("/+$", "") .. "/models"
	local header = api_of(provider) == "anthropic" and ("x-api-key: " .. key) or ("Authorization: Bearer " .. key)
	local ok = pcall(vim.system, {
		"curl", "-sS", "--max-time", "15", "-w", "\n%{http_code}", "-H", "@-", url,
	}, { text = true, stdin = header .. "\n" }, function(result)
		vim.schedule(function()
			local body, code = (result.stdout or ""):match("^(.*)\n(%d+)$")
			if result.code ~= 0 or not code then
				return cb(nil, vim.trim(result.stderr or "curl failed"))
			end
			if code ~= "200" then
				return cb(nil, "HTTP " .. code)
			end
			local decoded_ok, data = pcall(vim.json.decode, body)
			local list = decoded_ok and type(data) == "table" and (data.data or data.models) or nil
			if type(list) ~= "table" then
				return cb(nil, "unexpected /models reply")
			end
			local ids = {}
			for _, m in ipairs(list) do
				local id = type(m) == "table" and (m.id or m.name) or m
				if type(id) == "string" then
					table.insert(ids, id)
				end
			end
			table.sort(ids)
			cb(ids)
		end)
	end)
	if not ok then
		cb(nil, "curl is not installed")
	end
end

-- Calls every provider's /models: reports what works and saves the model
-- lists for providers that do not list their models in the config.
-- `done` runs once every provider answered.
function M.check(done)
	local names = vim.tbl_keys(config.providers)
	table.sort(names)
	local lines = {}
	for _, line in ipairs(problems()) do
		if not line:find("no models") then
			table.insert(lines, "! " .. line)
		end
	end
	if #names == 0 then
		notify(table.concat(lines, "\n"), vim.log.levels.WARN)
		return
	end
	local found = read_json(discovered_path()) or {}
	local pending = #names
	local results = {}
	for _, name in ipairs(names) do
		fetch_models(config.providers[name], function(ids, err)
			if ids then
				found[name] = ids
				results[name] = ("✓ %s: %d models"):format(name, #ids)
			else
				results[name] = ("✗ %s: %s"):format(name, err)
			end
			pending = pending - 1
			if pending == 0 then
				write_file(discovered_path(), vim.json.encode(found))
				for _, n in ipairs(names) do
					table.insert(lines, results[n])
				end
				table.insert(lines, "default model: " .. (M.default_model() or "(none)"))
				notify(table.concat(lines, "\n"))
				if done then
					done()
				end
			end
		end)
	end
end

return M
