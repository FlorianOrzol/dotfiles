#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container exec
# Reads a saved command from the database and executes it on the remote container
# using 'pct exec'. This avoids the need to type long commands manually.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local cmd_alias="${ARG_ALIAS[0]:-${ARGS_EXTENSION_ARRAY[1]}}"

    if [[ -z "$ctid" || -z "$cmd_alias" ]]; then
        output --error "Usage: lpex server container exec <CTID> <Alias>"
        return 1
    fi

    init_command_db

    # 1. Fetch the exact command string from the database
    local raw_cmd
    raw_cmd=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" "SELECT command FROM device_commands WHERE target_type='container' AND target_id='$ctid' AND alias='$cmd_alias';" 2>/dev/null)
    
    if [[ -z "$raw_cmd" ]]; then
        output --error "Alias '$cmd_alias' not found for container $ctid in local memory."
        return 1
    fi

    # 2. Execute the command securely over SSH via pct exec
    output --section "Executing '$cmd_alias' on CT $ctid"
    output --info "Command: $raw_cmd"
    
    # We remove --quiet so the user sees the direct output of their command in the terminal!
    lx cmd --run "ssh root@$active_host 'pct exec $ctid -- bash -c \"$raw_cmd\"'" \
           --log --log-tags "exec,$cmd_alias" \
           --no-error-msg
           
    # Note: If the command fails, the output will be printed, and the overall script 
    # will return the exact exit code of the executed command.
}
