local M = {}

vim.g.cherry_pairs = {
	default = {
		{ "{", "}" },
		{ "[", "]" },
		{ "(", ")" },
	},
	vim = {
		{ "if", "endif" },
		{ "function", "endfunction" },
		{ "while", "endwhile" },
		{ "for", "endfor" },
		{ "try", "endtry" },
	},
	sh = {
		{ "if", "fi" },
		{ "for", "done" },
		{ "while", "done" },
		{ "case", "esac" },
	},
	lua = {
		{ "function", "end" },
		{ "if", "end" },
		{ "do", "end" },
		{ "repeat", "until" },
	},
}

local function setup()
	for i, list in ipairs(vim.g.cherry_highlights) do
		local hi_cmd = "highlight Cherry-" .. i
		for key, val in pairs(list) do
			hi_cmd = hi_cmd .. " " .. key .. "=" .. val
		end
		vim.cmd(hi_cmd)
	end

	vim.t.current_cherry_pairs = vim.g.cherry_pairs["default"]
	if vim.g.cherry_pairs[vim.bo.filetype] == nil then
		return
	end
	local temp_table = vim.t.current_cherry_pairs
	for _, pair in pairs(vim.g.cherry_pairs[vim.bo.filetype]) do
		if temp_table[pair[1]] ~= nil then
			error("CHERRY ERROR: Opening word " .. pair[1] .. " already exists")
		end
		table.insert(temp_table, pair)
	end
	vim.t.current_cherry_pairs = temp_table
end

local function highlight()
	local temp_table = vim.t.highlights
	if temp_table == nil then
		return
	end
	for i, result in pairs(vim.t.cherry_results) do
		local match_id = vim.fn.matchaddpos("Cherry-" .. i, result)
		temp_table[tostring(match_id)] = result
	end
	vim.t.highlights = temp_table
end

-- @param[range] range of lines to be cleared {1, 3}
local function clear_matches(range)
	if vim.t.highlights == nil then
		return
	end

	local temp_table = vim.t.highlights
	for id, val in pairs(vim.t.highlights) do
		local delete_match = true
		if range ~= nil then
			if val[1] < range[1] and val[2] > range[2] then
				delete_match = false
			end
		end
		if delete_match then
			temp_table[id] = nil
			vim.fn.matchdelete(tonumber(id))
		end
	end
	vim.t.highlights = temp_table
end

function M.update_pairs()
	if vim.treesitter.language.get_lang(vim.bo.filetype) == nil then
		return
	end

	if vim.t.cherry_setup == nil then
		setup()
		vim.t.highlights = {}
		vim.t.cherry_setup = 1
	end

	clear_matches()
	vim.t.cherry_results = {}
	local start_line = vim.api.nvim_call_function("line", { "w0" })
	local last_line = vim.api.nvim_call_function("line", { "w$" })
	vim.g.cherry_current_pos = vim.api.nvim_win_get_cursor(0)

	vim.g.cherry_results = {}
	for _, pair in pairs(vim.t.current_cherry_pairs) do
		local open = pair[1]
		local close = pair[2]
		vim.api.nvim_call_function("searchpair", {
			"\\m" .. open,
			"",
			"noop",
			"rcnbW", -- r:outest pair; c:match oncursor; n:do not move cursor; b:search backwards; W:don't  wrap around
			"getline('.') || g:Cherry_find_closing('" .. open .. "','" .. close .. "','" .. (last_line + 2) .. "')",
			start_line,
			30,
		})
	end
	highlight()
end

function M.cherry_validate_ts(start_pos_1, end_pos_1, bufnr)
	local start_pos = { start_pos_1[1] - 1, start_pos_1[2] - 1 }
	local end_pos = { end_pos_1[1] - 1, end_pos_1[2] - 1 }
	local start_node = vim.treesitter.get_node({ bufnr, pos = { start_pos[1], start_pos[2] } })
	local end_node = vim.treesitter.get_node({ bufnr, pos = { end_pos[1], end_pos[2] } })
	if start_node:id() == end_node:id() then
		return 0
	else
		return 1
	end
end

function M.cherry_aggregate_results(open, close, len_open, len_close)
	local open_str = { tostring(open[1]), tostring(open[2]) }
	local temp_table = vim.t.cherry_results
	local target_index = 1

	if table.getn(temp_table) ~= 0 then
		for i = 1, table.getn(temp_table), 1 do
			if
				tonumber(temp_table[i][1][1]) > open[1]
				or (tonumber(temp_table[i][1][1]) == open[1] and tonumber(temp_table[i][1][2]) > open[2])
			then
				target_index = i
				break
			elseif i == table.getn(temp_table) then
				target_index = i + 1
				break
			end
		end
	end
	table.insert(temp_table, target_index, {
		{ tonumber(open_str[1]), tonumber(open_str[2]), len_open },
		{ close[1], close[2], len_close },
	})
	vim.t.cherry_results = temp_table
end

return M
