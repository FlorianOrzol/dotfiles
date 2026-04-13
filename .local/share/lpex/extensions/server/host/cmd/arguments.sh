#!/bin/bash
# ==============================================================================
# @meta_module      : server host cmd
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server host cmd'.
#
# @arg_values       : --node  | Target Proxmox node (pve101, pve102, pve103)
# @arg_flags        : --run   | Execute the command or alias
# @arg_flags        : --save  | Save the command to the database
# @arg_flags        : --delete | Delete the specified alias from the database
# @arg_values       : --alias | Name of the macro (dynamic list from DB)
# @arg_values       : --cmd   | Raw bash command string
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Proxmox Node" --option "pve101" --option "pve102" --option "pve103"
    
    local current_node=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--node" ]] && current_node="${ARGS_ENTERED[i+1]}"
    done

    local list_cmd=""
    if [[ -n "$current_node" ]]; then
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # ' || command FROM device_commands WHERE target_type='host' AND target_id='$current_node';\" 2>/dev/null"
    else
        list_cmd="sqlite3 ~/.local/state/lpex/data/server/commands.db \"SELECT alias || ' # Node:' || target_id FROM device_commands WHERE target_type='host';\" 2>/dev/null"
    fi
    
    arg_flag  @run    --description "Execute the command or alias"
    arg_flag  @save   --description "Save the command to the database"
    arg_flag  @delete --description "Delete the specified alias from the database"
    arg_flag  @list   --description "List all saved macros for the target node"

    arg_value @alias  --option-cmd "$list_cmd" --description "The name of the macro"
    arg_value @cmd    --description "The raw bash command string"
}
