local M = {}

local default_config = {
	languages = {
		default = {
			pairs = {
				{ "{", "}" },
				{ "[", "]" },
				{ "(", ")" },
			},
		},
		vim = {
			pairs = {
				{ "if", "endif" },
				{ "function", "endfunction" },
				{ "while", "endwhile" },
				{ "for", "endfor" },
				{ "try", "endtry" },
			},
		},
		sh = {
			pairs = {
				{ "if", "fi" },
				{ "for", "done" },
				{ "while", "done" },
				{ "case", "esac" },
			},
			allowed_doubles = {
				{ "(" },
				{ "[" },
			},
		},
		lua = {
			pairs = {
				{ "function", "end" },
				{ "if", "end" },
				{ "do", "end" },
				{ "repeat", "until" },
			},
		},
		["yaml.ansible"] = {
			allowed_doubles = {
				{ "{" },
			},
		},
	},
	highlights = {
		{ guibg = "red", guifg = "black", gui = "bold" },
		{ guibg = "orange", guifg = "black", gui = "bold" },
		{ guibg = "yellow", guifg = "black", gui = "bold" },
		{ guibg = "green", guifg = "black", gui = "bold" },
		{ guibg = "cyan", guifg = "black", gui = "bold" },
		{ guibg = "blue", guifg = "black", gui = "bold" },
		{ guibg = "magenta", guifg = "black", gui = "bold" },
		{ guibg = "white", guifg = "black", gui = "bold" },
	},
}

local config = {}
config.languages = default_config.languages

function M.setup(override_config)
	if override_config.highlights ~= nil then
		config.highlights = override_config.highlights
	else
		config.highlights = default_config.highlights
	end
	if override_config.languages ~= nil then
		for lang in pairs(override_config.languages) do
			if override_config.languages[lang].pairs ~= nil then
				for _, pair in pairs(override_config.languages[lang].pairs) do
					local unique_pair = true
					for _, default_pair in pairs(default_config.languages[lang].pairs) do
						if pair[1] == default_pair[1] then
							unique_pair = false
							break
						end
					end
					if unique_pair then
						table.insert(config.languages[lang].pairs, { pair[1], pair[2] })
					end
				end
			end
		end
	end

	for i, list in ipairs(config.highlights) do
		local hi_cmd = "highlight Cherry" .. i
		for key, val in pairs(list) do
			hi_cmd = " " .. hi_cmd .. " " .. key .. "=" .. val
		end
		vim.cmd(hi_cmd)
	end
end

local function init_buffer()
	vim.t.current_cherry_pairs = config.languages["default"].pairs
	if config.languages[vim.bo.filetype] == nil or config.languages[vim.bo.filetype].pairs == nil then
		return
	end
	local temp_table = vim.t.current_cherry_pairs
	for _, pair in pairs(config.languages[vim.bo.filetype].pairs) do
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
		local match_id = vim.fn.matchaddpos("Cherry" .. i, result)
		temp_table[tostring(match_id)] = result
	end
	vim.cmd("silent set guicursor")
	vim.t.highlights = temp_table
end

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

local function check_doubles()
	local temp_table = {}
	local i = 1
	local bufnr = vim.fn.bufnr("%")
	while i <= #vim.t.cherry_results do
		if i == #vim.t.cherry_results then
			table.insert(temp_table, vim.t.cherry_results[i])
			break
		end
		local cur_pair = vim.t.cherry_results[i]
		local next_pair = vim.t.cherry_results[i + 1]
		local start_node_1 = vim.treesitter.get_node({ bufnr, pos = { cur_pair[1][1] - 1, cur_pair[1][2] - 1 } })
		local end_node_1 = vim.treesitter.get_node({ bufnr, pos = { cur_pair[2][1] - 1, cur_pair[2][2] - 1 } })
		local start_node_2 = vim.treesitter.get_node({ bufnr, pos = { next_pair[1][1] - 1, next_pair[1][2] - 1 } })
		local end_node_2 = vim.treesitter.get_node({ bufnr, pos = { next_pair[2][1] - 1, next_pair[2][2] - 1 } })

		if start_node_1 == nil or end_node_1 == nil or start_node_2 == nil or end_node_2 == nil then
			print("WARNING Cherry could not find treesitter node")
			table.insert(temp_table, vim.t.cherry_results[i])
			i = i + 1
		else
			if start_node_1:id() == end_node_2:id() and start_node_2:id() == start_node_1:id() then
				local temp_el = { vim.t.cherry_results[i][1], vim.t.cherry_results[i + 1][2] }
				temp_el[1][3] = vim.t.cherry_results[i][1][3] + vim.t.cherry_results[i + 1][1][3]
				temp_el[2][3] = vim.t.cherry_results[i][2][3] + vim.t.cherry_results[i + 1][2][3]
				table.insert(temp_table, temp_el)
				i = i + 2
			else
				table.insert(temp_table, vim.t.cherry_results[i])
				i = i + 1
			end
		end
	end
	vim.t.cherry_results = temp_table
end

function M.update_pairs()
	if vim.treesitter.language.get_lang(vim.bo.filetype) == nil then
		return
	end

	if vim.t.cherry_buffer_init == nil then
		init_buffer()
		vim.t.highlights = {}
		vim.t.cherry_buffer_init = 1
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
	if config.languages[vim.bo.filetype] ~= nil and config.languages[vim.bo.filetype].allowed_doubles ~= nil then
		check_doubles()
	end

	highlight()
end

vim.cmd("redir >> debug")
function M.cherry_validate_ts(start_pos_1, end_pos_1, bufnr)
	local start_pos = { start_pos_1[1] - 1, start_pos_1[2] - 1 }
	local end_pos = { end_pos_1[1] - 1, end_pos_1[2] - 1 }
	local start_node = vim.treesitter.get_node({ bufnr, pos = { start_pos[1], start_pos[2] } })
	local end_node = vim.treesitter.get_node({ bufnr, pos = { end_pos[1], end_pos[2] } })
	if start_node == nil or end_node == nil then
		return 1
	end
	if start_node:type() == "while_statement" then
		end_node = end_node:parent()
		if end_node == nil then
			return 1
		end
	end
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

	if #temp_table ~= 0 then
		for i = 1, #temp_table, 1 do
			if
				tonumber(temp_table[i][1][1]) > open[1]
				or (tonumber(temp_table[i][1][1]) == open[1] and tonumber(temp_table[i][1][2]) > open[2])
			then
				target_index = i
				break
			elseif i == #temp_table then
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
