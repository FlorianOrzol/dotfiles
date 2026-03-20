function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid --fzf --description "Target Container ID (Use 'global' for global scripts)" --option-cmd "$(get_lxc_completion_cmd)"
    arg_flag @global --description "Manage global scripts instead of container-specific ones"
        
    local current_ctid=""
    local is_global=0
    local check_array=("${ARGS_ENTERED[@]}" "${ARGS_EXTENSION_ARRAY[@]}")
    for (( i=0; i<${#check_array[@]}; i++ )); do
        [[ "${check_array[i]}" == "--ctid" ]] && current_ctid="${check_array[i+1]}"
        [[ "${check_array[i]}" == "--global" ]] && is_global=1
    done

    local list_cmd=""
    if (( is_global )); then
        list_cmd="find ~/.local/state/lpex/data/server/global/container/scripts/ -maxdepth 1 -type f 2>/dev/null | xargs -n 1 basename 2>/dev/null"
    elif [[ -n "$current_ctid" ]]; then
        list_cmd="find ~/.local/state/lpex/data/server/container/$current_ctid/scripts/ -maxdepth 1 -type f 2>/dev/null | xargs -n 1 basename 2>/dev/null"
    else
        list_cmd="find ~/.local/state/lpex/data/server/ -type f -path '*/scripts/*' 2>/dev/null | awk -F'/data/server/' '{print \$2}'"
    fi

    arg_value @add --description "Create a new script (Enter filename)"
    arg_value @edit --option-cmd "$list_cmd" --description "Edit an existing script"
    arg_value @delete --option-cmd "$list_cmd" --description "Delete an existing script"
}
