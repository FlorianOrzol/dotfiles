#!/bin/bash
function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid --multi --fzf --description "Target Container(s)" --option-cmd "$(get_lxc_completion_cmd)"
        
    local current_ctid=""
    local check_array=("${ARGS_ENTERED[@]}" "${ARGS_EXTENSION_ARRAY[@]}")
    for (( i=0; i<${#check_array[@]}; i++ )); do
        [[ "${check_array[i]}" == "--ctid" ]] && current_ctid="${check_array[i+1]}"
    done

    # We now use 'find .' without '-type f' so directories are also shown in completion!
    local list_cmd=""
    if [[ -n "$current_ctid" ]]; then
        list_cmd="cd ~/.local/state/lpex/data/server/container/$current_ctid/filesystem/ 2>/dev/null && find . | sed 's|^./||' | grep -v '^$'"
    else
        list_cmd="find ~/.local/state/lpex/data/server/ -path '*/filesystem/*' 2>/dev/null | awk -F'/filesystem/' '{print \$2}' | grep -v '^$' | sort | uniq"
    fi
    
    arg_value @local_file --multi --option-cmd "$list_cmd" --description "Select file or directory from local filesystem to push"
}
