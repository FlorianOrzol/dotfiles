#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container filesystem
# ==============================================================================

function arguments() {
    
    arg_value @ctid --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    arg_flag  @global --description "Manage the global filesystem pool instead of a specific container"
        
    # Extract scope for targeted autocompletions
    local current_ctid=""
    local is_global=0
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--ctid" ]] && current_ctid="${ARGS_ENTERED[i+1]}"
        [[ "${ARGS_ENTERED[i]}" == "--global" ]] && is_global=1
    done

    # --- Dynamic File Tree Generation ---
    local list_cmd=""
    if (( is_global )); then
        list_cmd="cd ~/.local/state/lpex/data/server/global/container/filesystem/ 2>/dev/null && find . -type f | sed 's|^./||'"
    elif [[ -n "$current_ctid" ]]; then
        list_cmd="cd ~/.local/state/lpex/data/server/container/$current_ctid/filesystem/ 2>/dev/null && find . -type f | sed 's|^./||'"
    else
        # Fallback showing all paths across the framework
        list_cmd="find ~/.local/state/lpex/data/server/ -type f -path '*/filesystem/*' 2>/dev/null | awk -F'/filesystem/' '{print \$2}' | sort | uniq"
    fi

    # Action flags
    arg_value @add    --description "Create a new local file or fetch an existing one from the server"
    arg_value @edit   --option-cmd "$list_cmd" --description "Edit an existing local file in Neovim"
    arg_value @delete --option-cmd "$list_cmd" --description "Delete an existing local file or directory"
    arg_flag  @remote --description "Used with --delete: Synchronously delete the file/folder on the remote container"
}
