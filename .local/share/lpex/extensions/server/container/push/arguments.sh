function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid --multi --fzf --description "Target Container(s)" --option-cmd "$(get_lxc_completion_cmd)"
        
    local current_ctid=""
    local check_array=("${ARGS_ENTERED[@]}" "${ARGS_EXTENSION_ARRAY[@]}")
    for (( i=0; i<${#check_array[@]}; i++ )); do
        [[ "${check_array[i]}" == "--ctid" ]] && current_ctid="${check_array[i+1]}"
    done

    local list_cmd=""
    if [[ -n "$current_ctid" ]]; then
        list_cmd="find ~/.local/state/lpex/data/server/container/$current_ctid/configs/ ~/.local/state/lpex/data/server/global/container/configs/ -maxdepth 1 -type f 2>/dev/null | xargs -n 1 basename 2>/dev/null | sort | uniq"
    else
        list_cmd="find ~/.local/state/lpex/data/server/ -type f -path '*/configs/*' 2>/dev/null | awk -F'/data/server/' '{print \$2}'"
    fi
    
    arg_value @local_file --multi --option-cmd "$list_cmd" --description "Select local config file to push"
    arg_value @remote_dest --description "Absolute destination path INSIDE the container (e.g. /etc/nginx/nginx.conf)"
}
