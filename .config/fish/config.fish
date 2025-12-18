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



set -gx EDITOR nvim
# set global variables
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

function dotfiles
	set -l repo $argv[1]
	if test $repo = "public"
		git --git-dir=$HOME/.git-dotfiles/public --work-tree=$HOME $argv[2..-1]
	else if test $repo = "private"
		git --git-dir=$HOME/.git-dotfiles/private --work-tree=$HOME $argv[2..-1]
	else
		echo "Usage: dotfiles [public|private] [git-commands]"
	end
end
	

function _lhu
	set -l currentDir (pwd)
	cd ~/software-development/linux-helper/
	make uninstall
	make install
	cd $currentDir
end

function _lhue
	_lhu
	linux-helper -xd $argv 
end

#function x
#	linux-helper -xd $argv
#end

set GITprivateGitSSH 'git@10.0.11.15:flo/'
set GITpublicGitSSH 'git@github.com:FlorianOrzol/'
set GITprogPushAllGitRepos '/home/florian/software-development/git-handling/push-all-git-repos.sh'
set GITpathsGitRepos '/home/florian/software-development' '~/public-dotfiles'




function mygit-push
	set -l gitUrl $argv[1]
	set -e argv[1]
	if test argv[1] = "commit:"
		set -e argv[1]
	end


	#check if argv[1] begins with "commit:" and delete commit: from string
	if string match -q "commit:*" $argv[1]
		set  firstArg (string replace "commit:" "" $argv[1])
		set -e argv[1]
	end

	set commitMessage "$firstArg $argv"

	echo "full commit: $commitMessage"
	

	if test -f $GITprogPushAllGitRepos
		for path in $GITpathsGitRepos
			$GITprogPushAllGitRepos $path $gitUrl "$commitMessage"
		end
	end
end


alias git-private-push="mygit-push $GITprivateGitSSH "


#complete -c mytest -n '__fish_use_subcommand' -f -a (helptext)
complete -c git-private-push -f -a "commit: " -d "" 
alias ttt="/home/florian/test.sh"
# complete -c mytest -n '__fish_use_subcommand' -f -a (helptext)
#complete -c mytest -n '__fish_use_subcommand' -f -a (mytest $argv)

#function ttt
#	/home/florian/test.sh $argv
#end
#complete -c ttt -f -a '(/home/florian/test.sh first)' 

function ffzf
	set -g fzf (command /usr/bin/fzf -m --header='(Ctrl-o) open file in editor' --bind='ctrl-o:execute(open ./{})' --height=20 --layout reverse --margin=0,3,0,3 --color 16 $argv)
	echo $fzf
end


function save_status --on-event fish_postexec
    set -g last_status $status
end




function fish_user_key_bindings
	#bind \co 'ranger-cd ; commandline -f execute; commandline -f repaint'
	bind \co 'cd-ranger; commandline -f execute;'
	#    bind \co 'ranger-cd ; '

end
