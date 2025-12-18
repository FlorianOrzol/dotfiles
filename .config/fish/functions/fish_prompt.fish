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
	set -l status_sign "ᐱ" #ᐱ    ✔    λ

    if set -q last_status
        if test $last_status -eq 0
            # proof exit status of last command
            set color_status (set_color 00FF00)
            set status_sign "ᐱ" #ᐱ    ✔    λ
        else
            set color_status (set_color red)
            set status_sign "✘"
        end
    else
            set color_status (set_color 00FF00)
            set status_sign "ᐱ" #ᐱ    ✔    λ
    end

    # if it is inside a git repository, show the informative status.
    # this prevent the errot that the git status is not a git repository 
    set -l git_info ""
    if string match -q '*(*' (__fish_git_prompt)
        set git_info "$color_fg_git " (__fish_git_prompt) "$color_fg_git_status " (__fish_git_prompt_informative_status)
        #echo (__fish_git_prompt_informative_status)"
    end


    echo -s "$color_fg_hellgrey" "╭─" "$color_fg_grey" "" "$color_status" "$color_bg_grey" "$status_sign" $color_fg_hellgrey" ╱ "  "$color_fg_blue" (pwd) " " "$git_info" "$color_normal" "$color_fg_grey" "▓▒░" "$color_normal" 
    echo -s "$color_fg_hellgrey" "╰─ " "$color_normal"
end
