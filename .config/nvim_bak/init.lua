
-- Set the leader key to space

vim.g.mapleader = ' '

-- tab settings
vim.opt.tabstop = 4 -- Number of spaces that a <Tab> in the file counts for
vim.opt.shiftwidth = 4 -- Number of spaces to use for each step of (auto)indent
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.smartindent = true -- Insert indents automatically
vim.opt.autoindent = false -- Copy indent from current line when starting a new line

vim.opt.packpath = vim.fn.stdpath('data') .. '/site'
vim.opt.packpath:append('/home/florian/public-dotfiles/.config/nvim')
vim.opt.runtimepath:append('/home/florian/public-dotfiles/.config/nvim')

vim.cmd [[packadd packer.nvim]]

--vim.opt.runtimepath:append('~/public-dotfiles/.config/nvim/site')

require('packer').startup(function()
    use { 'wbthomason/packer.nvim' }
    use 'gitub.com/copilot.vim'
    use 'CopilotC-Nvim/CopilotChat.nvim'
    use 'nvim-lua/plenary.nvim'
end)




-- Set the colorscheme
-- ===================

-- vim.cmd('colorscheme gruvbox')
-- vim.cmd('colorscheme gruvbox-material')
-- vim.cmd('colorscheme gruvbox-flat')
-- vim.cmd('colorscheme desert')
-- vim.cmd('colorscheme elflord')
-- vim.cmd('colorscheme evening')
-- vim.cmd('colorscheme industry')
-- vim.cmd('colorscheme koehler')
-- vim.cmd('colorscheme morning')
-- vim.cmd('colorscheme murphy')
-- vim.cmd('colorscheme pablo')
-- vim.cmd('colorscheme peachpuff')
-- vim.cmd('colorscheme ron')
-- vim.cmd('colorscheme shine')
-- vim.cmd('colorscheme slate')
-- vim.cmd('colorscheme torte')
-- vim.cmd('colorscheme vim')
vim.cmd('colorscheme evening')


local allModes = {
    'n', -- normal
    'i', -- insert
    'v', -- visual
}

-- set normal mode when arrow keys are pressed and move the cursor in the direction of the arrow key
vim.api.nvim_set_keymap('i', '<up>', '<esc><up>', {noremap = true})
vim.api.nvim_set_keymap('i', '<down>', '<esc><down>', {noremap = true})
vim.api.nvim_set_keymap('i', '<left>', '<esc>', {noremap = true})
vim.api.nvim_set_keymap('i', '<right>', '<esc><right>', {noremap = true})

-- move the rows up and down
vim.api.nvim_set_keymap('n', '<A-j>', ':move +1<CR>gv', {noremap = true})
vim.api.nvim_set_keymap('n', '<A-k>', ':move -2<CR>gv', {noremap = true})
vim.api.nvim_set_keymap('v', '<A-j>', ':move \'>+1<CR>gv', {noremap = true})
vim.api.nvim_set_keymap('v', '<A-k>', ':move \'<-2<CR>gv', {noremap = true})
vim.api.nvim_set_keymap('i', '<A-j>', '<esc>:m .+1<CR>==', {noremap = true})
vim.api.nvim_set_keymap('i', '<A-k>', '<esc>:m .-2<CR>==', {noremap = true})

-- When uncommented and set to true, line numbers will be displayed in the gutter.

-- Set number lines in Neovim.
vim.opt.number = true

-- Set relative number lines in Neovim.
-- When uncommented and set to true, relative line numbers will be displayed in the gutter.
-- This can help in quickly identifying the number of lines between the cursor and a specific line.
vim.opt.relativenumber = true


-- Enable highlighting of the current line in Neovim.
-- When uncommented and set to true, the line where the cursor is located will be highlighted.
-- This can help in identifying the current cursor position.
vim.opt.cursorline = true


-- Enable highlighting of the screen column of the cursor in Neovim.
-- When uncommented and set to true, the column where the cursor is located will be highlighted.
-- This can help in identifying the current cursor position in wide lines.
-- vim.opt.cursorcolumn = true


-- Disable line wrapping in Neovim.
-- When set to false, long lines will not wrap and will extend beyond the window width.
-- This requires horizontal scrolling to view the entire line.
vim.opt.wrap = true 


-- Ctrl+l to move to the right window
vim.api.nvim_set_keymap('n', '<C-l>', '<C-w>l', {noremap = true, silent = true})
vim.api.nvim_set_keymap('n', '<C-h>', '<C-w>h', {noremap = true, silent = true})
vim.api.nvim_set_keymap('n', '<C-j>', '<C-w>j', {noremap = true, silent = true})
vim.api.nvim_set_keymap('n', '<C-k>', '<C-w>k', {noremap = true, silent = true})


-- Ctrl+Shift+l to resize the window
vim.api.nvim_set_keymap('n', '<C-S-l>', ':vertical resize +5<CR>', {noremap = true, silent = true})
vim.api.nvim_set_keymap('n', '<C-S-h>', ':vertical resize -5<CR>', {noremap = true, silent = true})
vim.api.nvim_set_keymap('n', '<C-S-k>', ':resize +5<CR>', {noremap = true, silent = true})
vim.api.nvim_set_keymap('n', '<C-S-j>', ':resize -5<CR>', {noremap = true, silent = true})



-- tab navigation
vim.api.nvim_set_keymap('n', 'tw', ':tabnew<CR>', {noremap = true, silent = true}) -- new empty tab with tw
vim.api.nvim_set_keymap('n', 'tx', ':tabclose<CR>', {noremap = true, silent = true}) -- close tab with tx
vim.api.nvim_set_keymap('n', 'tl', ':tabnext<CR>', {noremap = true, silent = true}) -- move to the next tab with tn
vim.api.nvim_set_keymap('n', 'th', ':tabprevious<CR>', {noremap = true, silent = true}) -- move to the previous tab with tp
vim.api.nvim_set_keymap('n', 'tt', ':tabmove<CR>', {noremap = true, silent = true}) -- move window to the tab with tt



-- Load the Copilot configuration module
require('copilot-config')


