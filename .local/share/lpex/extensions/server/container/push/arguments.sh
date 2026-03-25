#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container push
# ==============================================================================

function arguments() {
    
    arg_value @ctid --multi --fzf --description "Target Container(s)" --option-cmd "$(get_lxc_completion_cmd)"
        
    local current_ctid=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--ctid" ]] && current_ctid="${ARGS_ENTERED[i+1]}"
    done

    # Dynamic File Tree for Autocompletion
    local list_cmd=""
    if [[ -n "$current_ctid" ]]; then
        list_cmd="cd ~/.local/state/lpex/data/server/container/$current_ctid/filesystem/ 2>/dev/null && find . | sed 's|^./||' | grep -v '^$'"
    else
        list_cmd="find ~/.local/state/lpex/data/server/ -path '*/filesystem/*' 2>/dev/null | awk -F'/filesystem/' '{print \$2}' | grep -v '^$' | sort | uniq"
    fi
    
    arg_value @local_file --multi --option-cmd "$list_cmd" --description "Select file or directory from local filesystem to push"
}
