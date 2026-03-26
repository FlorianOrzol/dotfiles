#!/bin/bash
function arguments() {
    arg_value @node --multi --description "Target Proxmox Node(s)" --option "pve101" --option "pve102" --option "pve103"
        
    local current_node=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--node" ]] && current_node="${ARGS_ENTERED[i+1]}"
    done

    local list_cmd=""
    if [[ -n "$current_node" ]]; then
        list_cmd="cd ~/.local/state/lpex/data/server/host/$current_node/filesystem/ 2>/dev/null && find . | sed 's|^./||' | grep -v '^$'"
    else
        list_cmd="find ~/.local/state/lpex/data/server/host/ -path '*/filesystem/*' 2>/dev/null | awk -F'/filesystem/' '{print \$2}' | grep -v '^$' | sort | uniq"
    fi
    
    arg_value @local_file --multi --option-cmd "$list_cmd" --description "Select file or directory from local filesystem to push"
}
