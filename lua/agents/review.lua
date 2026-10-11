-- Review comments on an agent's diff. In the diff preview, `c` comments on
-- the line under the cursor; `S` sends every comment to the agent as one
-- prompt. Comments stay per agent until they are sent.
local M = {}

local ns = vim.api.nvim_create_namespace("agents_review")
local comments = {} -- agent name -> list of { path, line, code, text }

function M.count(name)
	return comments[name] and #comments[name] or 0
end

-- New-file line number for a line of `git diff` output, from the hunk header
-- "@@ -a,b +c,d @@" above it. Removed lines get the position they were at.
local function file_line(lines, index)
	local new_line
	for i = 1, index do
		local line = lines[i]
		local start = line:match("^@@ %-%d+,?%d* %+(%d+)")
		if start then
			new_line = tonumber(start) - 1
		elseif new_line then
			local first = line:sub(1, 1)
			if i == index then
				return new_line + 1, line:sub(2)
			end
			if first == "+" or first == " " then
				new_line = new_line + 1
			end
		end
	end
end

local function show(buf, name, path)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, c in ipairs(comments[name] or {}) do
		if c.path == path and c.row and c.row < vim.api.nvim_buf_line_count(buf) then
			vim.api.nvim_buf_set_extmark(buf, ns, c.row, 0, {
				virt_text = { { "  ● " .. c.text, "DiagnosticInfo" } },
				virt_text_pos = "eol",
			})
		end
	end
end

-- Wires `c` (comment) into a diff preview buffer for one file of an agent.
function M.attach(buf, name, path)
	show(buf, name, path)
	vim.keymap.set("n", "c", function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local line, code = file_line(lines, row)
		if not line then
			vim.notify("Put the cursor on a changed line inside a hunk", vim.log.levels.WARN, { title = "Agents" })
			return
		end
		vim.ui.input({ prompt = ("Comment on %s:%d: "):format(path, line) }, function(text)
			if not text or vim.trim(text) == "" then
				return
			end
			comments[name] = comments[name] or {}
			table.insert(comments[name], { path = path, line = line, code = vim.trim(code or ""), text = vim.trim(text), row = row - 1 })
			show(buf, name, path)
		end)
	end, { buffer = buf, nowait = true, desc = "Comment on this line" })
end

-- The prompt that carries all pending comments, or nil when there are none.
function M.take(name)
	local list = comments[name]
	if not list or #list == 0 then
		return nil
	end
	local out = { "Review comments on your changes. Please address each one:", "" }
	for _, c in ipairs(list) do
		local code = c.code ~= "" and (" (`" .. c.code:sub(1, 80) .. "`)") or ""
		table.insert(out, ("- %s:%d%s: %s"):format(c.path, c.line, code, c.text))
	end
	comments[name] = nil
	return table.concat(out, "\n")
end

function M.clear(name)
	comments[name] = nil
end

return M
