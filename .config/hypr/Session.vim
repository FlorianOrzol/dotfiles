let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/.dotfiles/public/.config/hypr
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +31 hyprland.conf
badd +0 scripts/workspaces.sh
argglobal
%argdel
$argadd hyprland.conf
edit hyprland.conf
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
2wincmd h
wincmd w
wincmd _ | wincmd |
split
1wincmd k
wincmd w
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 140 + 210) / 421)
exe '2resize ' . ((&lines * 42 + 43) / 86)
exe 'vert 2resize ' . ((&columns * 140 + 210) / 421)
exe '3resize ' . ((&lines * 41 + 43) / 86)
exe 'vert 3resize ' . ((&columns * 140 + 210) / 421)
exe 'vert 4resize ' . ((&columns * 139 + 210) / 421)
argglobal
setlocal foldmethod=manual
setlocal foldexpr=0
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
silent! normal! zE
let &fdl = &fdl
let s:l = 235 - ((0 * winheight(0) + 42) / 84)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 235
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("scripts/workspaces.sh", ":p")) | buffer scripts/workspaces.sh | else | edit scripts/workspaces.sh | endif
if &buftype ==# 'terminal'
  silent file scripts/workspaces.sh
endif
setlocal foldmethod=manual
setlocal foldexpr=0
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
silent! normal! zE
let &fdl = &fdl
let s:l = 341 - ((16 * winheight(0) + 21) / 42)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 341
normal! 054|
lcd ~/.dotfiles/public/.config/hypr
wincmd w
argglobal
if bufexists(fnamemodify("~/.dotfiles/public/.config/hypr/scripts/workspaces.sh", ":p")) | buffer ~/.dotfiles/public/.config/hypr/scripts/workspaces.sh | else | edit ~/.dotfiles/public/.config/hypr/scripts/workspaces.sh | endif
if &buftype ==# 'terminal'
  silent file ~/.dotfiles/public/.config/hypr/scripts/workspaces.sh
endif
setlocal foldmethod=manual
setlocal foldexpr=0
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
silent! normal! zE
let &fdl = &fdl
let s:l = 374 - ((10 * winheight(0) + 20) / 41)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 374
normal! 064|
lcd ~/.dotfiles/public/.config/hypr
wincmd w
argglobal
if bufexists(fnamemodify("~/.dotfiles/public/.config/hypr/scripts/workspaces.sh", ":p")) | buffer ~/.dotfiles/public/.config/hypr/scripts/workspaces.sh | else | edit ~/.dotfiles/public/.config/hypr/scripts/workspaces.sh | endif
if &buftype ==# 'terminal'
  silent file ~/.dotfiles/public/.config/hypr/scripts/workspaces.sh
endif
setlocal foldmethod=manual
setlocal foldexpr=0
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable
silent! normal! zE
let &fdl = &fdl
let s:l = 587 - ((26 * winheight(0) + 42) / 84)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 587
normal! 031|
lcd ~/.dotfiles/public/.config/hypr
wincmd w
3wincmd w
exe 'vert 1resize ' . ((&columns * 140 + 210) / 421)
exe '2resize ' . ((&lines * 42 + 43) / 86)
exe 'vert 2resize ' . ((&columns * 140 + 210) / 421)
exe '3resize ' . ((&lines * 41 + 43) / 86)
exe 'vert 3resize ' . ((&columns * 140 + 210) / 421)
exe 'vert 4resize ' . ((&columns * 139 + 210) / 421)
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20
let &shortmess = s:shortmess_save
let &winminheight = s:save_winminheight
let &winminwidth = s:save_winminwidth
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
set hlsearch
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
