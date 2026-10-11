-- Small text-canvas helpers shared by the hub panels and the office view.
-- A canvas is lines plus highlight ranges; segments are { text, hl_group? }.
local M = {}

local ns = vim.api.nvim_create_namespace("agents")

M.width = vim.fn.strdisplaywidth

function M.trunc(text, max)
	if max <= 0 then
		return ""
	end
	if M.width(text) <= max then
		return text
	end
	return vim.fn.strcharpart(text, 0, max - 1) .. "…"
end

function M.trunc_left(text, max)
	if M.width(text) <= max then
		return text
	end
	local chars = vim.fn.strchars(text)
	return "…" .. vim.fn.strcharpart(text, chars - (max - 1))
end

function M.seg_width(segs)
	local total = 0
	for _, seg in ipairs(segs) do
		total = total + M.width(seg[1])
	end
	return total
end

-- Joins left and right segments so the right ones end at the panel edge.
function M.row(left, right, total)
	right = right or {}
	local gap = total - M.seg_width(left) - M.seg_width(right)
	local out = vim.list_extend({}, left)
	table.insert(out, { string.rep(" ", math.max(gap, 1)) })
	return vim.list_extend(out, right)
end

function M.new_canvas()
	return { lines = {}, hls = {}, line_hls = {} }
end

function M.push(canvas, segs, line_hl)
	local text = ""
	local lnum = #canvas.lines
	for _, seg in ipairs(segs) do
		if seg[2] then
			table.insert(canvas.hls, { lnum, #text, #text + #seg[1], seg[2] })
		end
		text = text .. seg[1]
	end
	table.insert(canvas.lines, text)
	if line_hl then
		canvas.line_hls[lnum] = line_hl
	end
	return lnum + 1
end

function M.paint(buf, canvas)
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, canvas.lines)
	vim.bo[buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for lnum, group in pairs(canvas.line_hls) do
		vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, { line_hl_group = group, priority = 10 })
	end
	for _, hl in ipairs(canvas.hls) do
		vim.api.nvim_buf_set_extmark(buf, ns, hl[1], hl[2], { end_col = hl[3], hl_group = hl[4], priority = 20 })
	end
end

function M.age(seconds)
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m"
	end
	return math.floor(seconds / 3600) .. "h"
end

function M.diffstat(add, del)
	local segs = {}
	if add > 0 then
		table.insert(segs, { "+" .. add, "AgentsAdd" })
	end
	if del > 0 then
		if #segs > 0 then
			table.insert(segs, { " " })
		end
		table.insert(segs, { "−" .. del, "AgentsDel" })
	end
	return segs
end

return M
