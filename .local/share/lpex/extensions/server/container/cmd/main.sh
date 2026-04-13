#!/bin/bash
# ==============================================================================
# @meta_module      : server container cmd
# @meta_file        : main.sh
# @meta_date        : 2026-04-11
#
# @desc_short       : Executes raw bash commands or saved macros inside an LXC container.
# @desc_detailed    : Supports ad-hoc command execution via 'pct exec', saving commands
# @desc_detailed    : as named macros in a local SQLite database, and running macros by
# @desc_detailed    : alias. Commands are Base64-encoded and piped to bash inside the
# @desc_detailed    : container to safely handle any special characters or nested quotes.
#
# @arg_flags        : --run    | Execute the command string or the loaded alias
# @arg_flags        : --save   | Persist the command under the given alias name
# @arg_flags        : --delete | Remove a stored alias from the database
# @arg_flags        : --list   | Print all saved macros for the target container
# @arg_values       : --ctid   | Target Container ID (dynamic from NFS cache)
# @arg_values       : --alias  | Name of the macro to save, run, or delete
# @arg_values       : --cmd    | Raw bash command string to execute or save
#
# @exit_codes       : 0 | Success or no-op
# @exit_codes       : 1 | Missing required argument or DB error
# ==============================================================================

function extension_start() {
    enforce_config_var "USER_PVE"

    local active_host=$(get_active_host)
    local ctid="${ARG_CTID[0]}"

    if [[ -z "$ctid" ]]; then
        output --error "Please specify a Container ID (--ctid)."
        return 1
    fi

    init_command_db

    local alias_name="${ARG_ALIAS[0]}"
    local raw_cmd="${ARG_CMD[0]}"

    # ==========================================================================
    # --- Feature: Macro List ---
    # ==========================================================================
    if (( ARG_LIST )); then
        output --section "Saved Macros for CT $ctid"

        local results
        results=$(sqlite3 "$PATH_EXTENSION_DATA/commands.db" \
            "SELECT alias, command FROM device_commands WHERE target_type='container' AND target_id='$ctid' ORDER BY alias;" \
            2>/dev/null)

        if [[ -z "$results" ]]; then
            output --warn "No macros saved for CT $ctid yet."
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
        output --info "Deleting macro '$alias_name' for CT $ctid..."
        local sql_alias="${alias_name//\'/\'\'}"
        local sql="DELETE FROM device_commands WHERE target_type='container' AND target_id='$ctid' AND alias='$sql_alias';"
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
            "SELECT command FROM device_commands WHERE target_type='container' AND target_id='$ctid' AND alias='$alias_name';" \
            2>/dev/null)
        if [[ -z "$raw_cmd" ]]; then
            output --error "Saved alias '$alias_name' not found for CT $ctid."
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
            "SELECT command FROM device_commands WHERE target_type='container' AND target_id='$ctid' AND alias='$alias_name';" \
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
            local sql="REPLACE INTO device_commands (target_type, target_id, alias, command) VALUES ('container', '$ctid', '$sql_alias', '$sql_cmd');"
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
    # The command is Base64-encoded locally and decoded inside the container.
    # This avoids all quoting issues in the pct exec → bash -c chain, which would
    # otherwise break on commands containing double quotes or nested subshells.
    # ==========================================================================
    if (( ARG_RUN )); then
        output --section "Executing Command on CT $ctid"
        output --info "$raw_cmd"

        local tag="cmd"
        (( loaded_from_db )) && tag="cmd,macro"
        (( ARG_SAVE ))       && tag="cmd,saved"

        # [LOGIC] Encode the raw command as Base64 (-w0 = no line wrapping).
        # The SSH command pipes the base64 string into 'pct exec -- bash', which
        # reads the decoded script from stdin. This avoids the nested-quoting
        # breakage that occurs with 'pct exec -- bash -c "..."'.
        local encoded_cmd
        encoded_cmd=$(printf '%s' "$raw_cmd" | base64 -w0)

        lx cmd --run "ssh $USER_PVE@$active_host \"printf '%s' '$encoded_cmd' | base64 -d | pct exec $ctid -- bash\"" \
               --log --log-tags "$tag" \
               --no-error-msg
    else
        output --warn "No action requested. Use --run, --save, --delete, or --list."
    fi
}
