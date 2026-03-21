#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container cmd-add
# Saves a specific command to the local SQLite database so it can be 
# easily autocompleted and executed later via the 'exec' module.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local ctid="${ARG_CTID[0]:-${ARGS_EXTENSION_ARRAY[0]}}"
    local cmd_alias="${ARG_ALIAS[0]:-${ARGS_EXTENSION_ARRAY[1]}}"
    local cmd_string="${ARG_CMD[0]:-${ARGS_EXTENSION_ARRAY[2]}}"

    if [[ -z "$ctid" || -z "$cmd_alias" || -z "$cmd_string" ]]; then
        output --error "Usage: lpex server container cmd-add <CTID> <Alias> <Command>"
        return 1
    fi

    # Ensure the database table exists before we try to write to it
    init_command_db

    output --info "Saving command for CT $ctid..."
    
    # We use SQLite REPLACE to overwrite the command if the alias already exists
    # Requires raw SQL execution because the current lx db wrapper defaults to strict INSERT
    local sql="REPLACE INTO device_commands (target_type, target_id, alias, command) VALUES ('container', '$ctid', '$cmd_alias', '$cmd_string');"
    
    if lx db --file "commands.db" --exec "$sql" --quiet; then
        output --ok "Command '$cmd_alias' saved successfully."
    else
        output --error "Failed to save command to database."
        return 1
    fi
}
