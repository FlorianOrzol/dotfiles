#!/bin/bash
function arguments() {
    arg_value @node --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    
    local current_node=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--node" ]] && current_node="${ARGS_ENTERED[i+1]}"
    done

    local list_cmd=""
    if [[ -n "$current_node" ]]; then
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # ' || command FROM device_commands WHERE target_type='observer' AND target_id='$current_node';\" 2>/dev/null"
    else
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # Node:' || target_id FROM device_commands WHERE target_type='observer';\" 2>/dev/null"
    fi
    
    arg_flag  @run    --description "Execute the command or alias"
    arg_flag  @save   --description "Save the command to the database"
    arg_flag  @delete --description "Delete the specified alias from the database"
    
    arg_value @alias  --option-cmd "$list_cmd" --description "The name of the macro"
    arg_value @cmd    --description "The raw bash command string"
}
