#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server container cmd
# Description: A unified CLI interface to execute ad-hoc bash commands inside 
# a container, save frequently used commands as macros in an SQLite database,
# and execute those saved macros effortlessly.
# ==============================================================================

function extension_start() {
    source "$(dirname "${BASH_SOURCE[0]}")/../../server_lib.sh"
    
    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]}"

    if [[ -z "$ctid" ]]; then
        output --error "Please specify a Container ID (--ctid)."
        return 1
    fi

    # Ensure the command database and tables exist
    init_command_db

    local raw_cmd="${ARG_CMD[0]}"
    local alias_name="${ARG_ALIAS[0]}"

    # ==========================================================================
    # --- ACTION: DELETE ---
    # ==========================================================================
    if (( ARG_DELETE )); then
        if [[ -z "$alias_name" ]]; then
            output --error "Please specify the macro to delete (--alias <name>)."
            return 1
        fi
        output --info "Deleting macro '$alias_name' for CT $ctid..."
        local sql="DELETE FROM device_commands WHERE target_type='container' AND target_id='$ctid' AND alias='$alias_name';"
        if lx db --file "commands.db" --exec "$sql" --quiet; then
            output --ok "Deleted successfully."
        else
            output --error "Failed to delete macro."
        fi
        return 0 # Exit early, delete is a standalone action
    fi

    # ==========================================================================
    # --- RESOLVE COMMAND ---
    # If the user wants to RUN but didn't provide a raw command, they MUST 
    # have provided an alias to load from the DB.
    # ==========================================================================
    local loaded_from_db=0
    if (( ARG_RUN )) && [[ -z "$raw_cmd" ]]; then
        if [[ -z "$alias_name" ]]; then
            output --error "Nothing to run. Provide either --cmd <string> or --alias <name>."
            return 1
        fi
        
        raw_cmd=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" "SELECT command FROM device_commands WHERE target_type='container' AND target_id='$ctid' AND alias='$alias_name';" 2>/dev/null)
        
        if [[ -z "$raw_cmd" ]]; then
            output --error "Saved alias '$alias_name' not found for CT $ctid."
            return 1
        fi
        output --info "Loaded macro: $alias_name"
        loaded_from_db=1
    fi

    # ==========================================================================
    # --- ACTION: SAVE (With Overwrite Protection) ---
    # ==========================================================================
    if (( ARG_SAVE )); then
        if [[ -z "$alias_name" || -z "$raw_cmd" ]]; then
            output --error "To save a macro, you must provide both --alias <name> and --cmd <string>."
            return 1
        fi
        
        # Check if alias already exists to warn the user
        local existing_cmd
        existing_cmd=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" "SELECT command FROM device_commands WHERE target_type='container' AND target_id='$ctid' AND alias='$alias_name';" 2>/dev/null)
        
        if [[ -n "$existing_cmd" ]] && [[ "$existing_cmd" != "$raw_cmd" ]]; then
            output --warn "Alias '$alias_name' already exists!"
            output --warn "Old Command: $existing_cmd"
            output --warn "New Command: $raw_cmd"
            if ! question "Do you want to overwrite it?" --default-no; then
                output --info "Save cancelled."
                # If they only wanted to save, exit. If they also wanted to run, we continue to run.
                (( ! ARG_RUN )) && return 0
                ARG_SAVE=0 # Prevent the actual save logic below from running
            fi
        fi

        # Proceed with saving
        if (( ARG_SAVE )); then
            output --info "Saving command as macro '$alias_name'..."
            local sql="REPLACE INTO device_commands (target_type, target_id, alias, command) VALUES ('container', '$ctid', '$alias_name', '$raw_cmd');"
            if lx db --file "commands.db" --exec "$sql" --quiet; then
                output --ok "Macro saved."
            else
                output --error "Failed to save macro."
                return 1
            fi
        fi
        
        # If the user only wanted to save, terminate here.
        if (( ! ARG_RUN )); then
            return 0
        fi
    fi

    # ==========================================================================
    # --- EXECUTION ENGINE ---
    # ==========================================================================
    if (( ARG_RUN )); then
        if [[ -z "$raw_cmd" ]]; then
            output --error "No command provided to execute."
            return 1
        fi

        output --section "Executing Command on CT $ctid"
        output --info "$raw_cmd"
        
        local tag="cmd"
        (( loaded_from_db )) && tag="cmd,macro"
        (( ARG_SAVE )) && tag="cmd,saved"
        
        # We omit --quiet so the interactive output of the command (like apt-get progress)
        # is streamed directly back to the user's terminal.
        lx cmd --run "ssh root@$active_host 'pct exec $ctid -- bash -c \"$raw_cmd\"'" \
               --log --log-tags "$tag" \
               --no-error-msg
    else
        output --warn "No action requested. Use --run, --save, or --delete."
    fi
}
