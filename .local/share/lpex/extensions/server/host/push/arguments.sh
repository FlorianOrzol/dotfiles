#!/bin/bash
# ==============================================================================
# @meta_module      : server host push
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server host push'.
#
# @arg_values       : --node        | Target Proxmox node(s), repeatable (--multi)
# @arg_values       : --local-file  | Remote destination path (relative, tree-mirror; or '.' for all)
# @arg_values       : --source-path | Absolute local path to push directly (bypasses tree-mirror)
#
# @notes            : --source-path + --local-file: source-path is the local file,
# @notes            :   local-file determines the remote destination path only.
# ==============================================================================
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
    
    arg_value @local_file  --multi --option-cmd "$list_cmd" --description "Remote destination path (relative, tree-mirror; or '.' for everything)"
    arg_value @source_path --description "Absolute local path of the file to push (bypasses tree-mirror lookup)"
}
