#!/bin/bash
# ==============================================================================
# @meta_module      : server host filesystem
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server host filesystem'.
#
# @arg_values       : --node      | Target Proxmox node (pve101, pve102, pve103)
# @arg_flags        : --global    | Operate on the shared global host pool
# @arg_values       : --add       | Path to create locally (Smart Vault check)
# @arg_values       : --edit      | Path to open in editor (autocomplete from local tree)
# @arg_values       : --delete    | Path to delete locally
# @arg_flags        : --remote    | Used with --delete: also remove on the host
# @arg_flags        : --no-vault  | Skip Smart Vault check for known-new files
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Proxmox Node (pve101, pve102, pve103)" --option "pve101" --option "pve102" --option "pve103"
    arg_flag  @global --description "Manage the global host filesystem pool"
        
    local current_node=""
    local is_global=0
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--node" ]] && current_node="${ARGS_ENTERED[i+1]}"
        [[ "${ARGS_ENTERED[i]}" == "--global" ]] && is_global=1
    done

    local list_cmd=""
    if (( is_global )); then
        list_cmd="cd ~/.local/state/lpex/data/server/global/host/filesystem/ 2>/dev/null && find . -type f | sed 's|^./||'"
    elif [[ -n "$current_node" ]]; then
        list_cmd="cd ~/.local/state/lpex/data/server/host/$current_node/filesystem/ 2>/dev/null && find . -type f | sed 's|^./||'"
    else
        list_cmd="find ~/.local/state/lpex/data/server/host/ -type f -path '*/filesystem/*' 2>/dev/null | awk -F'/filesystem/' '{print \$2}' | sort | uniq"
    fi

    arg_value @add      --description "Create a new local file or fetch an existing one"
    arg_value @edit     --option-cmd "$list_cmd" --description "Edit an existing local file"
    arg_value @delete   --option-cmd "$list_cmd" --description "Delete an existing local file or directory"
    arg_flag  @remote   --description "Used with --delete: Synchronously delete on the remote Host"
    arg_flag  @no_vault --description "Skip the Smart Vault remote check (use for known-new files)"
}
