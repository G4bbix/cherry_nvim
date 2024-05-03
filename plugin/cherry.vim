function g:Cherry_find_closing(opening_str, closing_str, last_line)
	let s:open = [line('.'), col('.')]
	let s:current_buffer = bufnr('%')
	let s:close = searchpairpos('\V' . a:opening_str, '', '\V' . a:closing_str, 'W',
		\ "v:lua.require'cherry'.cherry_validate_ts(s:open, [line('.'), col('.')], s:current_buffer)",
		\ a:last_line, 500)

	if s:verify_scope()
		call v:lua.require'cherry'.cherry_aggregate_results(s:open, s:close, len(a:opening_str), len(a:closing_str))
	endif
	return 0
endfunction

function s:verify_scope()
	if s:close[0] > g:cherry_current_pos[0]
		return 1
	elseif s:close[0] == g:cherry_current_pos[0] &&
		\ s:close[1] >= g:cherry_current_pos[1]
		return 1
	else
		return 0
	endif
endfunction

