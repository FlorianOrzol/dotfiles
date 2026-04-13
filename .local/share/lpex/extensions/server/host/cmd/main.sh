#!/bin/bash
# ==============================================================================
# @meta_module      : server host cmd
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Executes raw bash commands or saved macros on a bare-metal host.
# @desc_detailed    : Supports ad-hoc execution via SSH, saving commands as named
# @desc_detailed    : macros in a local SQLite database, and running macros by alias.
# @desc_detailed    : Commands are Base64-encoded before transmission to safely handle
# @desc_detailed    : any special characters, quotes or newlines in the command string.
#
# @arg_flags        : --run    | Execute the command string or the loaded alias
# @arg_flags        : --save   | Persist the command under the given alias name
# @arg_flags        : --delete | Remove a stored alias from the database
# @arg_flags        : --list   | Print all saved macros for the target node
# @arg_values       : --node   | Target Proxmox node (pve101, pve102, pve103)
# @arg_values       : --alias  | Name of the macro to save, run, or delete
# @arg_values       : --cmd    | Raw bash command string to execute or save
#
# @exit_codes       : 0 | Success or no-op
# @exit_codes       : 1 | Missing required argument, IP resolution failure, DB error
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_PVE"

    local node="${ARG_NODE[0]}"
    if [[ -z "$node" ]]; then
        output --error "Please specify a Proxmox Node (--node)."
        return 1
    fi

    local node_upper="${node^^}"
    local ip_var="IP_${node_upper}"
    local ip="${!ip_var}"
    if [[ -z "$ip" ]]; then
        output --error "Failed to resolve IP for $node. Define $ip_var in config.conf."
        return 1
    fi

    init_command_db

    local alias_name="${ARG_ALIAS[0]}"
    local raw_cmd="${ARG_CMD[0]}"

    # ==========================================================================
    # --- Feature: Macro List ---
    # Displays all saved macros for the node as a formatted table and exits.
    # ==========================================================================
    if (( ARG_LIST )); then
        output --section "Saved Macros for $node"

        local results
        results=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" \
            "SELECT alias, command FROM device_commands WHERE target_type='host' AND target_id='$node' ORDER BY alias;" \
            2>/dev/null)

        if [[ -z "$results" ]]; then
            output --warn "No macros saved for $node yet."
            output --info "Save one with: --cmd <cmd> --alias <name> --save"
            return 0
        fi

        while IFS='|' read -r alias cmd; do
            output --ok "  $(printf '%-22s' "$alias")  │  $cmd"
        done <<< "$results"
        return 0
    fi

    # ==========================================================================
    # --- Feature: Macro Deletion ---
    # ==========================================================================
    if (( ARG_DELETE )); then
        if [[ -z "$alias_name" ]]; then
            output --error "Please specify the macro to delete (--alias <name>)."
            return 1
        fi
        output --info "Deleting macro '$alias_name' for $node..."
        local sql_alias="${alias_name//\'/\'\'}"
        local sql="DELETE FROM device_commands WHERE target_type='host' AND target_id='$node' AND alias='$sql_alias';"
        if lx db --file "commands.db" --exec "$sql" --quiet; then
            output --ok "Deleted successfully."
        else
            output --error "Failed to delete macro."
        fi
        return 0
    fi

    # ==========================================================================
    # --- Feature: Command Resolution (Alias Fetch) ---
    # ==========================================================================
    local loaded_from_db=0
    if (( ARG_RUN )) && [[ -z "$raw_cmd" ]]; then
        if [[ -z "$alias_name" ]]; then
            output --error "Nothing to run. Provide either --cmd <string> or --alias <name>."
            return 1
        fi
        raw_cmd=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" \
            "SELECT command FROM device_commands WHERE target_type='host' AND target_id='$node' AND alias='$alias_name';" \
            2>/dev/null)
        if [[ -z "$raw_cmd" ]]; then
            output --error "Saved alias '$alias_name' not found for $node."
            return 1
        fi
        output --info "Loaded macro: $alias_name"
        loaded_from_db=1
    fi

    if [[ -z "$raw_cmd" ]]; then
        output --error "No command provided. Use --cmd <command> or --alias <name> with --run."
        return 1
    fi

    # ==========================================================================
    # --- Feature: Macro Saving & Overwrite Protection ---
    # ==========================================================================
    if (( ARG_SAVE )); then
        if [[ -z "$alias_name" || -z "$raw_cmd" ]]; then
            output --error "To save a macro, provide both --alias <name> and --cmd <string>."
            return 1
        fi
        local existing_cmd
        existing_cmd=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" \
            "SELECT command FROM device_commands WHERE target_type='host' AND target_id='$node' AND alias='$alias_name';" \
            2>/dev/null)
        if [[ -n "$existing_cmd" ]] && [[ "$existing_cmd" != "$raw_cmd" ]]; then
            output --warn "Alias '$alias_name' already exists!"
            output --warn "Old: $existing_cmd"
            output --warn "New: $raw_cmd"
            if ! question "Do you want to overwrite it?" --default-no; then
                output --info "Save cancelled."
                (( ! ARG_RUN )) && return 0
                ARG_SAVE=0
            fi
        fi
        if (( ARG_SAVE )); then
            output --info "Saving command as macro '$alias_name'..."
            local sql_alias="${alias_name//\'/\'\'}"
            local sql_cmd="${raw_cmd//\'/\'\'}"
            local sql="REPLACE INTO device_commands (target_type, target_id, alias, command) VALUES ('host', '$node', '$sql_alias', '$sql_cmd');"
            if lx db --file "commands.db" --exec "$sql" --quiet; then
                output --ok "Macro saved."
            else
                output --error "Failed to save macro."
                return 1
            fi
        fi
        (( ! ARG_RUN )) && return 0
    fi

    # ==========================================================================
    # --- Feature: Remote Execution Engine (Base64-safe) ---
    # Base64-encodes the command before transmission so that any special
    # characters, quotes or newlines in the command string survive the SSH
    # argument chain without escaping or quoting issues.
    # ==========================================================================
    if (( ARG_RUN )); then
        output --section "Executing Command on $node"
        output --info "$raw_cmd"

        local tag="cmd"
        (( loaded_from_db )) && tag="cmd,macro"
        (( ARG_SAVE ))       && tag="cmd,saved"

        # [LOGIC] Encode the command to Base64 (-w0 disables line-wrapping).
        # On the remote, printf|base64 -d reconstructs the exact original string
        # and pipes it to bash. The -t flag allocates a PTY for interactive sudo.
        local encoded_cmd
        encoded_cmd=$(printf '%s' "$raw_cmd" | base64 -w0)

        lx cmd --run "ssh -t $USER_PVE@$ip \"printf '%s' '$encoded_cmd' | base64 -d | bash\"" \
               --log --log-tags "$tag" \
               --no-error-msg
    else
        output --warn "No action requested. Use --run, --save, --delete, or --list."
    fi
}
