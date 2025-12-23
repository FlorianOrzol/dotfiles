#
#  _____
# |~>   |     _
# |_____|   ('v') 
# /:::::\  /{w w}\ 
#
# created by: Florian Orzol
# my fish config file 
#
#    <')
# \_;( )
# >>>>>>><<<<<<<



# set global variables
set -gx EDITOR nvim
set -gx VISUAL nvim

zoxide init fish | source # zoxide is a smarter cd command
fnm env --use-on-cd | source # fnm is a node version manager
mcfly init fish | source # mcfly is a better history search tool


abbr -a l '_exa'
abbr -a ls '_exa'
abbr -a la '_exa -la'
abbr -a ll '_exa -l'
abbr -a lt '_exa -lT'
abbr -a lr '_exa -lR'
alias _exa='exa --icons --group-directories-first -M -h --git'
alias vim='nvim'
alias google-chrome-stable='/usr/bin/google-chrome-stable --enable-features=UseOzonePlatform --ozone-platform=x11'
abbr -a x 'linux-helper -xd'
abbr -a p 'keys get -c'





function ffzf
	set -g fzf (command /usr/bin/fzf -m --header='(Ctrl-o) open file in editor' --bind='ctrl-o:execute(open ./{})' --height=20 --layout reverse --margin=0,3,0,3 --color 16 $argv)
	echo $fzf
end





function save_status --on-event fish_postexec
    set -g last_status $status
end




function fish_user_key_bindings
	bind \co 'cd-ranger; commandline -f execute;'
end
