#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container cmd
# ==============================================================================

function arguments() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    arg_value @ctid --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    
    # Context-aware extraction of CTID for DB lookups
    local current_ctid=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--ctid" ]] && current_ctid="${ARGS_ENTERED[i+1]}"
    done

    # Dynamic DB Lookup Command for Autocompletion
    local list_cmd=""
    if [[ -n "$current_ctid" ]]; then
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # ' || command FROM device_commands WHERE target_type='container' AND target_id='$current_ctid';\" 2>/dev/null"
    else
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # CT:' || target_id FROM device_commands WHERE target_type='container';\" 2>/dev/null"
    fi
    
    # --- The Elegant Flags ---
    arg_flag  @run    --description "Execute the command or alias"
    arg_flag  @save   --description "Save the command to the database"
    arg_flag  @delete --description "Delete the specified alias from the database"
    
    arg_value @alias  --option-cmd "$list_cmd" --description "The name of the macro"
    arg_value @cmd    --description "The raw bash command string"
}
