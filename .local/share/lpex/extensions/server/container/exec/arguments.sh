#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container exec
# ==============================================================================

function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid \
        --fzf \
        --description "Target Container ID" \
        --option-cmd "$(get_lxc_completion_cmd)"
        
    # --- Context-Aware Command Completion ---
    # Extract the CTID that the user has currently typed
    local current_ctid=""
    local check_array=("${ARGS_ENTERED[@]}" "${ARGS_EXTENSION_ARRAY[@]}")
    for (( i=0; i<${#check_array[@]}; i++ )); do
        if [[ "${check_array[i]}" == "--ctid" ]]; then
            current_ctid="${check_array[i+1]}"
            break
        fi
    done

    # We build an option command that queries the SQLite database LIVE during completion.
    # It only fetches aliases that belong to the chosen container!
    local list_cmd=""
    if [[ -n "$current_ctid" ]]; then
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # ' || command FROM device_commands WHERE target_type='container' AND target_id='$current_ctid';\" 2>/dev/null"
    else
        # Fallback: show all container commands if no CTID is selected yet
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # CT:' || target_id FROM device_commands WHERE target_type='container';\" 2>/dev/null"
    fi
    
    arg_value @alias \
        --option-cmd "$list_cmd" \
        --description "Select a saved command to execute"
}
