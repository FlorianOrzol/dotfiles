#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container filesystem
# ==============================================================================

function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    arg_flag @global --description "Manage global filesystem instead of container-specific"
        
    local current_ctid=""
    local is_global=0
    local check_array=("${ARGS_ENTERED[@]}" "${ARGS_EXTENSION_ARRAY[@]}")
    for (( i=0; i<${#check_array[@]}; i++ )); do
        [[ "${check_array[i]}" == "--ctid" ]] && current_ctid="${check_array[i+1]}"
        [[ "${check_array[i]}" == "--global" ]] && is_global=1
    done

    # Context aware find for autocompletion
    local list_cmd=""
    if (( is_global )); then
        list_cmd="cd ~/.local/state/lpex/data/server/global/container/filesystem/ 2>/dev/null && find . -type f | sed 's|^./||'"
    elif [[ -n "$current_ctid" ]]; then
        list_cmd="cd ~/.local/state/lpex/data/server/container/$current_ctid/filesystem/ 2>/dev/null && find . -type f | sed 's|^./||'"
    else
        list_cmd="find ~/.local/state/lpex/data/server/ -type f -path '*/filesystem/*' 2>/dev/null | awk -F'/filesystem/' '{print \$2}' | sort | uniq"
    fi

    arg_value @add --description "Create a new file (e.g. etc/nginx/nginx.conf)"
    arg_value @edit --option-cmd "$list_cmd" --description "Edit an existing file"
    arg_value @delete --option-cmd "$list_cmd" --description "Delete an existing file"
}
