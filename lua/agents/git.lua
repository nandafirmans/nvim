-- Collects the working-tree changes an agent made, for the changes panel and
-- the per-agent +/- counts in the sidebar.
local M = {}

local MAX_UNTRACKED_BYTES = 512 * 1024

local function count_lines(path)
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.type ~= "file" or stat.size > MAX_UNTRACKED_BYTES then
		return nil
	end
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local content = file:read("*a")
	file:close()
	if content:find("\0", 1, true) then
		return nil
	end
	local _, newlines = content:gsub("\n", "")
	if #content > 0 and content:sub(-1) ~= "\n" then
		newlines = newlines + 1
	end
	return newlines
end

local function parse_status(stdout, cwd)
	local info = { branch = nil, files = {} }
	for line in vim.gsplit(stdout, "\n", { trimempty = true }) do
		if line:sub(1, 2) == "##" then
			local head = line:sub(4):gsub("^No commits yet on ", "")
			info.branch = head:match("^(.-)%.%.%.") or head:match("^(%S+)")
		else
			local code = line:sub(1, 2)
			local path = line:sub(4)
			local renamed = path:match(" %-> (.+)$")
			if renamed then
				path = renamed
			end
			local kind
			if code == "??" then
				kind = "?"
			elseif code:find("D") then
				kind = "D"
			elseif code:find("A") then
				kind = "A"
			elseif code:find("R") then
				kind = "R"
			elseif code:find("U") then
				kind = "U"
			else
				kind = "M"
			end
			local entry = { path = path, kind = kind, add = 0, del = 0 }
			if kind == "?" then
				entry.add = count_lines(cwd .. "/" .. path) or 0
			end
			table.insert(info.files, entry)
		end
	end
	return info
end

local function apply_numstat(info, stdout)
	local by_path = {}
	for _, entry in ipairs(info.files) do
		by_path[entry.path] = entry
	end
	for line in vim.gsplit(stdout or "", "\n", { trimempty = true }) do
		local add, del, path = line:match("^(%S+)\t(%S+)\t(.+)$")
		if path then
			-- Renames show as "old => new" or "dir/{old => new}".
			path = path:gsub("{.- => (.-)}", "%1"):gsub("^.- => ", "")
			local entry = by_path[path]
			if entry then
				entry.add = tonumber(add) or 0
				entry.del = tonumber(del) or 0
				entry.binary = add == "-"
			end
		end
	end
end

-- Calls cb({ branch, files, add, del }) on the main loop, or cb(nil) when cwd is not a repo.
function M.changes(cwd, cb)
	local base = { "git", "-C", cwd, "-c", "core.quotePath=false" }
	local pending, status_out, numstat_out, failed = 2, nil, nil, false

	local function finish()
		pending = pending - 1
		if pending > 0 then
			return
		end
		if failed then
			vim.schedule(function()
				cb(nil)
			end)
			return
		end
		local info = parse_status(status_out, cwd)
		apply_numstat(info, numstat_out)
		table.sort(info.files, function(a, b)
			return a.path < b.path
		end)
		info.add, info.del = 0, 0
		for _, entry in ipairs(info.files) do
			info.add = info.add + entry.add
			info.del = info.del + entry.del
		end
		vim.schedule(function()
			cb(info)
		end)
	end

	vim.system(
		vim.list_extend(vim.deepcopy(base), { "status", "--porcelain=v1", "-b", "--untracked-files=all" }),
		{ text = true },
		function(result)
			failed = failed or result.code ~= 0
			status_out = result.stdout or ""
			finish()
		end
	)
	vim.system(vim.list_extend(vim.deepcopy(base), { "diff", "--numstat", "HEAD" }), { text = true }, function(result)
		-- A repo without commits has no HEAD; the status output is still useful.
		numstat_out = result.code == 0 and result.stdout or ""
		finish()
	end)
end

function M.diff(cwd, entry, cb)
	local args = { "git", "-C", cwd, "-c", "core.quotePath=false", "--no-pager" }
	if entry.kind == "?" then
		vim.list_extend(args, { "diff", "--no-index", "--", "/dev/null", entry.path })
	else
		vim.list_extend(args, { "diff", "HEAD", "--", entry.path })
	end
	vim.system(args, { text = true }, function(result)
		vim.schedule(function()
			cb(vim.split(result.stdout or "", "\n", { trimempty = true }))
		end)
	end)
end

function M.root(path)
	return vim.fs.root(path, ".git")
end

-- Creates a worktree beside the repo, reusing the branch when it already exists.
function M.add_worktree(root, branch)
	local repo = vim.fs.basename(root)
	local path = vim.fs.joinpath(vim.fs.dirname(root), repo .. ".worktrees", (branch:gsub("/", "-")))
	if vim.uv.fs_stat(path) then
		return path
	end
	local exists = vim.system({ "git", "-C", root, "rev-parse", "--verify", "--quiet", "refs/heads/" .. branch }):wait()
	local args = { "git", "-C", root, "worktree", "add" }
	if exists.code == 0 then
		vim.list_extend(args, { path, branch })
	else
		vim.list_extend(args, { "-b", branch, path })
	end
	local result = vim.system(args, { text = true }):wait()
	if result.code ~= 0 then
		return nil, vim.trim(result.stderr or "")
	end
	return path
end

return M
