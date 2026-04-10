let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/.local/share/lpex/extensions/credentials
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +16 extension_global.sh
badd +0 add/arguments.sh
badd +0 add/main.sh
badd +0 ~/.local/state/lpex/data/credentials/config.conf
argglobal
%argdel
$argadd extension_global.sh
edit add/main.sh
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
wincmd _ | wincmd |
vsplit
3wincmd h
wincmd w
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
exe 'vert 1resize ' . ((&columns * 118 + 237) / 474)
exe 'vert 2resize ' . ((&columns * 118 + 237) / 474)
exe 'vert 3resize ' . ((&columns * 118 + 237) / 474)
exe 'vert 4resize ' . ((&columns * 117 + 237) / 474)
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
let s:l = 1 - ((0 * winheight(0) + 41) / 83)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
normal! 0
lcd ~/.local/share/lpex/extensions/credentials
wincmd w
argglobal
if bufexists(fnamemodify("~/.local/share/lpex/extensions/credentials/add/arguments.sh", ":p")) | buffer ~/.local/share/lpex/extensions/credentials/add/arguments.sh | else | edit ~/.local/share/lpex/extensions/credentials/add/arguments.sh | endif
if &buftype ==# 'terminal'
  silent file ~/.local/share/lpex/extensions/credentials/add/arguments.sh
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
let s:l = 7 - ((6 * winheight(0) + 41) / 83)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 7
normal! 0
lcd ~/.local/share/lpex/extensions/credentials
wincmd w
argglobal
if bufexists(fnamemodify("~/.local/share/lpex/extensions/credentials/extension_global.sh", ":p")) | buffer ~/.local/share/lpex/extensions/credentials/extension_global.sh | else | edit ~/.local/share/lpex/extensions/credentials/extension_global.sh | endif
if &buftype ==# 'terminal'
  silent file ~/.local/share/lpex/extensions/credentials/extension_global.sh
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
let s:l = 16 - ((15 * winheight(0) + 41) / 83)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 16
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/.local/state/lpex/data/credentials/config.conf", ":p")) | buffer ~/.local/state/lpex/data/credentials/config.conf | else | edit ~/.local/state/lpex/data/credentials/config.conf | endif
if &buftype ==# 'terminal'
  silent file ~/.local/state/lpex/data/credentials/config.conf
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
let s:l = 1 - ((0 * winheight(0) + 41) / 83)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
normal! 0
lcd ~/.local/share/lpex/extensions/credentials
wincmd w
4wincmd w
exe 'vert 1resize ' . ((&columns * 118 + 237) / 474)
exe 'vert 2resize ' . ((&columns * 118 + 237) / 474)
exe 'vert 3resize ' . ((&columns * 118 + 237) / 474)
exe 'vert 4resize ' . ((&columns * 117 + 237) / 474)
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
nohlsearch
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
