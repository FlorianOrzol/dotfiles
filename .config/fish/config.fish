#
#  _____
# |~>   |     _
# |_____|   ('v') 
# /:::::\  /{w w}\ 
#
# created by: Florian Orzol
# my fish config file 


#    <')
# \_;( )



if status is-interactive

# set global variables
set -gx EDITOR nvim
set -gx VISUAL nvim

# if it is inside a git repository, show the git status in exa (ls) command.
function get_git_status_for_exa
    if string match -q '*(*' (__fish_git_prompt)
        echo -en "--git"
    end
end

alias ls='exa --icons --group-directories-first -h (get_git_status_for_exa)'
alias vim='nvim'

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

function _e
	linux-helper -xd $argv
end

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
function mytest
	if test -z $argv[1]
		echo "test-eins test-zwei"
		return
	end
	if test $argv[1] = "test-eins"
		echo "1.1 1.2"
	else if test $argv[1] = "test-zwei"
		echo "2.1 2.2"
	end
end
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

function fish_prompt
    # set prompt colors
    set -l color_fg_hellgrey (set_color 585858)
    set -l color_fg_grey (set_color 303030)
    set -l color_bg_grey (printf "\033[48;5;240m")
    set -l color_bg_grey (printf "\033[48;5;236m")
    set -l color_fg_blue (set_color 0FABFF)

    set -l color_normal (set_color normal)
    set -l color_cwd (set_color cyan)
    set -l color_status (set_color red)
    set -l color_fg_git (set_color yellow)
    set -l color_fg_git_status (set_color CD6600)
    set -l status_sign

    if set -q last_status
        if test $last_status -eq 0
            # proof exit status of last command
            set color_status (set_color 00FF00)
            set status_sign ""
        else
            set color_status (set_color red)
            set status_sign "✘"
        end
    else
            set color_status (set_color 00FF00)
            set status_sign ""
    end

    # if it is inside a git repository, show the informative status.
    # this prevent the errot that the git status is not a git repository 
    set -l git_info ""
    if string match -q '*(*' (__fish_git_prompt)
        set git_info "$color_fg_git " (__fish_git_prompt) "$color_fg_git_status " (__fish_git_prompt_informative_status)
        #echo (__fish_git_prompt_informative_status)"
    end

    # show prompt
    #
    # ╭─(prompt_pwd)  -[ %~ ]-   -{ %n@%m }- ▓▒░
    # ╰─ %
    # bg: color_bg_grey

    echo -s "$color_fg_hellgrey" "╭─" "$color_fg_grey" "" "$color_status" "$color_bg_grey" "$status_sign" $color_fg_hellgrey" ╱ "  "$color_fg_blue" (prompt_pwd) " " "$git_info" "$color_normal" "$color_fg_grey" "▓▒░" "$color_normal" 
    echo -s "$color_fg_hellgrey" "╰─ " "$color_normal"
end


# ranger-cd changes the directory of the shell to the selected directory in ranger
function ranger-cd
    set tempfile '/tmp/chosendir'
    ranger --choosedir=$tempfile (pwd)
    if test -f $tempfile
        if [ (cat $tempfile) != (pwd) ]
            cd (cat $tempfile)
		end
    end
	rm -f $tempfile
end




function fish_user_key_bindings
	#bind \co 'ranger-cd ; commandline -f execute; commandline -f repaint'
	bind \co 'ranger-cd; commandline -f execute;'
	#    bind \co 'ranger-cd ; '
end

end
