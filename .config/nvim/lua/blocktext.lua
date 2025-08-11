--
-- 
--   _____        _
--  |~>   |     ('v') 
--  /:::::\    /{w w}\ 
-- --------------------------------
-- Copyright Florian Orzol
--
-- description:
-- date: 2024-10-26
-- version: 0.8.0
--
--    <')
-- \_;( )
-- >>>> START SCRIPT <<<< --
--



local function get_comment_systax()
	local filetype = vim.bo.filetype
	-- if filetypt is empty, check first line for shebang
	if filetype == '' then
		local shebang = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
		-- if shebang is not empty
		if shebang ~= '' then
			-- if shebang is lua
			if string.match(shebang, 'lua') then
				return '--', ''
			-- if shebang is python
			elseif string.match(shebang, 'python') then
				return '#', ''
			-- if shebang is sh
			elseif string.match(shebang, 'sh') then
				return '#', ''
			-- if shebang is vim
			elseif string.match(shebang, 'vim') then
				return '"', ''
			else
				return '//', ''
			end
		else
			return '//', ''
		end
	end
	if filetype == 'lua' then
		return '--', ''
	elseif filetype == 'python' then
		return '#', ''
	elseif filetype == 'sh' then
		return '#', ''
	elseif filetype == 'vim' then
		return '"', ''
	else 
		return '//', ''
	end
end









local function get_comment_systax_block()
	local filetype = vim.bo.filetype
	if filetype == 'lua' then
		return '--[[', ']]'
	elseif filetype == 'python' then
		return '"""', '"""'
	elseif filetype == 'sh' then
		return ':<<', 'EOF'
	elseif filetype == 'vim' then
		return '"', ''
	else 
		return '//', ''
	end
end









descriptionHeader = [[
#
#  
#   _____        _
#  |~>   |     ('v') 
#  /:::::\    /{w w}\ 
# --------------------------------
# Copyright Florian Orzol
#
# description:
# date: today
# version:  0.0.1
#
#    <')
# \_;( )
# >>>> START SCRIPT <<<< #
#
]]
function setDescriptionHeader(a)
	local comment = get_comment_systax()
	local final = a:gsub("#", comment)
	-- replace today with current date
	final = final:gsub("today", os.date("%Y-%m-%d"))
	
	-- insert header in file
	vim.api.nvim_put(vim.split(final, '\n'), 'l', true, true)
end









function setSection()
	-- user input
	local section = vim.fn.input('Section: ')
	-- get input length
	local len = string.len(section)
	-- add 8 to length
	local len = len + 10
	-- first line: <commentsign> and <= * len>
	local comment = get_comment_systax()
	local line = comment .. ' ' .. string.rep('=', len) .. ' ' .. comment
	-- second line: <commentsign> >>>> <user input> <<<< <commentsign>
	local line2 = comment .. ' >>>> ' .. section .. ' <<<< ' .. comment
	-- section upper case
	local section = string.upper(section)

	local line3 = comment
	-- if input is not empty
	if section ~= '' then
		-- third line: <commentsign> and <= * len>
		-- insert lines
		vim.api.nvim_put({line, line2, line, line3}, 'l', true, true)
	end
	
end









function replaceDate()

    local comment = get_comment_systax()
	-- save current cursor position
	local cursor = vim.api.nvim_win_get_cursor(0)
	-- set cursor to first line
	vim.api.nvim_win_set_cursor(0, {1, 0})
	-- search for <comment> date: yyyy-mm-dd in first 15 lines
    local line = vim.fn.search(comment .. ' date: ', 'nw', 15)

    if line > 0 then
		-- replace date with current date
        vim.api.nvim_buf_set_lines(0, line-1, line, false, {comment .. ' date: ' .. os.date("%Y-%m-%d")})
    else
        print("No date found")
    end
	-- set cursor back to original position
	vim.api.nvim_win_set_cursor(0, cursor)
end









function raiseVersion()
	local comment = get_comment_systax()
	-- save current cursor position
	local cursor = vim.api.nvim_win_get_cursor(0)
	-- set cursor to first line
	vim.api.nvim_win_set_cursor(0, {1, 0})
	-- search for <comment> version: x.x.x in first 15 lines
	local line = vim.fn.search(comment .. ' version: ', 'nw', 15)

	if line > 0 then
		-- get version
		local version = vim.api.nvim_buf_get_lines(0, line-1, line, false)[1]
		-- split version
		local major, minor, patch = string.match(version, '(%d+).(%d+).(%d+)')
		-- increment patch
		patch = patch + 1
		-- set new version
		vim.api.nvim_buf_set_lines(0, line-1, line, false, {comment .. ' version: ' .. major .. '.' .. minor .. '.' .. patch})
	else
		print("No version found")
	end
	-- set cursor back to original position
	vim.api.nvim_win_set_cursor(0, cursor)
end





vim.api.nvim_set_keymap('n', '<leader>th', ':lua setDescriptionHeader(descriptionHeader)<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>tm', ':lua setSection()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>td', ':lua replaceDate()<CR>', { noremap = true, silent = true, expr = false })
vim.api.nvim_set_keymap('n', '<leader>tv', ':lua raiseVersion()<CR>', { noremap = true, silent = true, expr = false })
-- update date and version
vim.api.nvim_set_keymap('n', '<leader>ta', ':lua replaceDate()<CR>:lua raiseVersion()<CR>', { noremap = true, silent = true, expr = false })


