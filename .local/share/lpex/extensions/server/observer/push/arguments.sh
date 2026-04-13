#!/bin/bash
# ==============================================================================
# @meta_module      : server observer push
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Declares CLI arguments for 'server observer push'.
#
# @arg_values       : --node        | Target Observer node (pi1 or pi2)
# @arg_values       : --local-file  | Relative path for remote dest (tree-mirror or "." for all)
# @arg_values       : --source-path | Absolute local path to push directly (bypasses tree-mirror)
#
# @notes            : --source-path + --local-file: source-path is the local file,
# @notes            :   local-file determines the remote destination path only.
# @notes            : Without --source-path: local-file is looked up in the tree-mirror.
# ==============================================================================
function arguments() {
    arg_value @node --multi --description "Target Observer node(s) — use multiple times for pi1 + pi2" --option "pi1" --option "pi2"

    # [LOGIC] Detect which node was selected so we can list node-specific files
    # in addition to the global pool. The node-specific files take precedence on push.
    local current_node=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--node" ]] && current_node="${ARGS_ENTERED[i+1]}"
    done

    local base="$HOME/.local/state/lpex/data/server"

    # Build a merged file list: node-specific entries first, then global pool.
    # 'sort -u' deduplicates paths that exist in both (global wins in completion display
    # but push logic will always prefer node-specific at runtime).
    local list_cmd
    if [[ -n "$current_node" ]]; then
        list_cmd="{ find '$base/observer/$current_node/filesystem' -type f 2>/dev/null | sed \"s|$base/observer/$current_node/filesystem/||\"; find '$base/global/observer/filesystem' -type f 2>/dev/null | sed \"s|$base/global/observer/filesystem/||\"; } | sort -u"
    else
        list_cmd="find '$base/global/observer/filesystem' -type f 2>/dev/null | sed \"s|$base/global/observer/filesystem/||\" | sort"
    fi

    arg_value @local_file  --multi --option-cmd "$list_cmd" --description "Remote destination path (relative, tree-mirror; or '.' for everything)"
    arg_value @source_path --description "Absolute local path of the file to push (bypasses tree-mirror lookup)"
}
