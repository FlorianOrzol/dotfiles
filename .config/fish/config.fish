#
#  _____
# |~>   |     _
# |_____|   ('v') 
# /:::::\  /{w w}\ 
# created by: Florian Orzol
# my fish config file 


#    <')
# \_;( )



if status is-interactive

# if it is inside a git repository, show the git status in exa (ls) command.
function get_git_status_for_exa
    if string match -q '*(*' (__fish_git_prompt)
        echo -en "--git"
    end
end

alias ls='exa --icons --group-directories-first -h (get_git_status_for_exa)'

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
        #echo (__fish_git_prompt_informative_status)
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
    bind \co 'ranger-cd ; commandline -f repaint'
end

end