#!/bin/bash
# ==============================================================================
# @meta_module      : server container push
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-12
#
# @desc_short       : Declares CLI arguments for 'server container push'.
#
# @arg_values       : --ctid        | Target container ID(s), repeatable (--multi)
# @arg_values       : --local-file  | Relative path for remote dest (tree-mirror or "." for all)
# @arg_values       : --source-path | Absolute local path to push directly (bypasses tree-mirror)
#
# @notes            : --source-path + --local-file: source-path is the local file,
# @notes            :   local-file determines the remote destination path only.
# @notes            : Without --source-path: local-file is looked up in the tree-mirror.
# ==============================================================================

function arguments() {

    arg_value @ctid --multi --fzf --description "Target Container(s)" --option-cmd "$(get_lxc_completion_cmd)"

    local current_ctid=""
    for (( i=0; i<${#ARGS_ENTERED[@]}; i++ )); do
        [[ "${ARGS_ENTERED[i]}" == "--ctid" ]] && current_ctid="${ARGS_ENTERED[i+1]}"
    done

    # Build a file list for autocompletion: container-specific entries, then global pool.
    local list_cmd=""
    if [[ -n "$current_ctid" ]]; then
        list_cmd="{ find ~/.local/state/lpex/data/server/container/$current_ctid/filesystem/ -type f 2>/dev/null | sed \"s|$HOME/.local/state/lpex/data/server/container/$current_ctid/filesystem/||\"; find ~/.local/state/lpex/data/server/global/container/filesystem/ -type f 2>/dev/null | sed \"s|$HOME/.local/state/lpex/data/server/global/container/filesystem/||\"; } | sort -u"
    else
        list_cmd="find ~/.local/state/lpex/data/server/global/container/filesystem/ -type f 2>/dev/null | sed \"s|$HOME/.local/state/lpex/data/server/global/container/filesystem/||\" | sort"
    fi

    arg_value @local_file  --multi --option-cmd "$list_cmd" --description "Remote destination path (relative, tree-mirror; or '.' for everything)"
    arg_value @source_path --description "Absolute local path of the file to push (bypasses tree-mirror lookup)"
}
