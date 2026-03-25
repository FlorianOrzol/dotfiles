#!/bin/bash
# ==============================================================================
# --- Arguments Definition ---
# Module: server observer push
# ==============================================================================
function arguments() {
    arg_value @node --description "Target Observer (pi1 or pi2)" --option "pi1" --option "pi2"
    
    local list_cmd="cd ~/.local/state/lpex/data/server/global/observer/ 2>/dev/null && find . -type f | sed 's|^./||'"
    arg_value @local_file --multi --option-cmd "$list_cmd" --description "File to push (from global observer payloads)"
}
