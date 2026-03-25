#!/bin/bash
# ==============================================================================
# --- Main Execution ---
# Module: server observer cmd
# Description: Executes raw bash commands or saved macros on the Observer Pi.
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_OBSERVER"
    
    local node="${ARG_NODE[0]}"
    if [[ -z "$node" ]]; then
        output --error "Please specify an Observer Node (--node)."
        return 1
    fi

    local ip=$(get_observer_ip "$node")
    init_command_db

    local save_alias="${ARG_SAVE[0]}"
    local delete_alias="${ARG_DELETE[0]}"
    local run_saved_alias="${ARG_RUN_SAVED[0]}"
    local raw_cmd="${ARG_CMD[0]}"

    if (( ARG_DELETE )); then
        if [[ -z "$alias_name" ]]; then
            output --error "Please specify the macro to delete (--alias <name>)."
            return 1
        fi
        output --info "Deleting macro '$alias_name' for $node..."
        local sql="DELETE FROM device_commands WHERE target_type='observer' AND target_id='$node' AND alias='$alias_name';"
        if lx db --file "commands.db" --exec "$sql" --quiet; then
            output --ok "Deleted successfully."
        else
            output --error "Failed to delete macro."
        fi
        return 0
    fi

    local loaded_from_db=0
    if (( ARG_RUN )) && [[ -z "$raw_cmd" ]]; then
        if [[ -z "$alias_name" ]]; then
            output --error "Nothing to run. Provide either --cmd <string> or --alias <name>."
            return 1
        fi
        
        raw_cmd=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" "SELECT command FROM device_commands WHERE target_type='observer' AND target_id='$node' AND alias='$alias_name';" 2>/dev/null)
        
        if [[ -z "$raw_cmd" ]]; then
            output --error "Saved alias '$alias_name' not found for $node."
            return 1
        fi
        output --info "Loaded macro: $alias_name"
        loaded_from_db=1
    fi

    if [[ -z "$raw_cmd" ]]; then
        output --error "No command provided. Use --cmd <command> or --run-saved <alias>."
        return 1
    fi

    if (( ARG_SAVE )); then
        if [[ -z "$alias_name" || -z "$raw_cmd" ]]; then
            output --error "To save a macro, you must provide both --alias <name> and --cmd <string>."
            return 1
        fi
        
        local existing_cmd
        existing_cmd=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" "SELECT command FROM device_commands WHERE target_type='observer' AND target_id='$node' AND alias='$alias_name';" 2>/dev/null)
        
        if [[ -n "$existing_cmd" ]] && [[ "$existing_cmd" != "$raw_cmd" ]]; then
            output --warn "Alias '$alias_name' already exists!"
            output --warn "Old Command: $existing_cmd"
            output --warn "New Command: $raw_cmd"
            if ! question "Do you want to overwrite it?" --default-no; then
                output --info "Save cancelled."
                (( ! ARG_RUN )) && return 0
                ARG_SAVE=0
            fi
        fi

        if (( ARG_SAVE )); then
            output --info "Saving command as macro '$alias_name'..."
            local sql="REPLACE INTO device_commands (target_type, target_id, alias, command) VALUES ('observer', '$node', '$alias_name', '$raw_cmd');"
            if lx db --file "commands.db" --exec "$sql" --quiet; then
                output --ok "Macro saved."
            else
                output --error "Failed to save macro."
                return 1
            fi
        fi
        
        if (( ! ARG_RUN )); then
            return 0
        fi
    fi

    if (( ARG_RUN )); then
        output --section "Executing Command on $node"
        output --info "$raw_cmd"
        
        local tag="cmd"
        (( loaded_from_db )) && tag="cmd,macro"
        (( ARG_SAVE )) && tag="cmd,saved"
        
        # -t is crucial for sudo commands that the user might have embedded in their macro
        lx cmd --run "ssh -t $USER_OBSERVER@$ip \"$raw_cmd\"" \
               --log --log-tags "$tag" \
               --no-error-msg
    else
        output --warn "No action requested. Use --run, --save, or --delete."
    fi
}
