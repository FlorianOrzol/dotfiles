#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server container cmd
# ==============================================================================

function arguments() {
    
    arg_value @ctid --fzf --description "Target Container ID" --option-cmd "$(get_lxc_completion_cmd)"
    
    # --- Feature: Context-Aware Database Lookup ---
    # We parse the entered arguments to extract the CTID early.
    # This allows us to query the SQLite DB to only show macro completions
    # that belong to the specific container the user is currently targeting.
    local current_ctid=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--ctid" ]] && current_ctid="${ARGS_ENTERED[i+1]}"
    done

    local list_cmd=""
    if [[ -n "$current_ctid" ]]; then
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # ' || command FROM device_commands WHERE target_type='container' AND target_id='$current_ctid';\" 2>/dev/null"
    else
        # Fallback: Show all macros across all containers if no CTID is specified yet
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # CT:' || target_id FROM device_commands WHERE target_type='container';\" 2>/dev/null"
    fi
    
    # --- Feature: Explicit Action Flags ---
    arg_flag  @run    --description "Execute the command or alias"
    arg_flag  @save   --description "Save the command to the database"
    arg_flag  @delete --description "Delete the specified alias from the database"
    
    # --- Feature: Data Inputs ---
    arg_value @alias  --option-cmd "$list_cmd" --description "The name of the macro"
    arg_value @cmd    --description "The raw bash command string"
}
