#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Main execution logic for the cmd submodule.
# ==============================================================================

# ==============================================================================
# --- function extension_start ---
# @desc_short       : Entry point called by the LPEX framework.
# @usage            : Automatically invoked after arguments.sh is processed.
# ==============================================================================
function extension_start {
    # 1. --- Validate Device Selection ---------------
    # ------ --list does not require a device; all other actions do.

    local device_type=""
    local target_device=""

    if [[ -z "$ARG_LIST" ]]; then
        _validate_device || return 1
        device_type="$_DEVICE_TYPE"
        target_device="$_DEVICE_ID"
    fi
    
    # 2. --- Validate Action Selection ---------------
    # ------ Ensure exactly one primary action is provided to avoid conflicting logic.
    
    local action_count=0
    
    [[ -n "$ARG_CMD" ]] && ((action_count++))
    [[ -n "$ARG_ALIAS" ]] && ((action_count++))
    [[ -n "$ARG_DELETE" ]] && ((action_count++))
    [[ -n "$ARG_EDIT" ]] && ((action_count++))
    [[ -n "$ARG_LIST" ]] && ((action_count++))
    
    if (( action_count == 0 )); then
        lx output --error "No action specified. Please provide --cmd, --alias, --delete, --edit, or --list."
        return 1
    elif (( action_count > 1 )); then
        lx output --error "Multiple actions specified. Please provide only one action at a time."
        return 1
    fi
    
    # 3. --- Action Routing ---------------
    # ------ Route execution flow based on the provided action.
    
    if [[ -n "$ARG_LIST" ]]; then
        _action_list
        return $?
    fi
    
    if [[ -n "$ARG_DELETE" ]]; then
        _action_delete
        return $?
    fi
    
    if [[ -n "$ARG_EDIT" ]]; then
        _action_edit
        return $?
    fi
    
    if [[ -n "$ARG_ALIAS" ]]; then
        _action_alias "$device_type" "$target_device"
        return $?
    fi
    
    if [[ -n "$ARG_CMD" ]]; then
        _action_cmd "$device_type" "$target_device"
        return $?
    fi
}

# ==============================================================================
# --- function _action_list ---
# @desc_short       : Lists all saved commands from cmds.db.
# ==============================================================================
function _action_list {
    # We use the 'lx db' command to print the entire table formatted to stdout.
    lx output --info "Listing all saved commands from cmds.db:"
    lx db --file "cmds.db" --table "commands" --select
}

# ==============================================================================
# --- function _action_delete ---
# @desc_short       : Deletes a specific command alias from cmds.db.
# ==============================================================================
function _action_delete {
    lx output --info "Deleting alias: $ARG_DELETE"
    lx db --file "cmds.db" --table "commands" --delete --where "alias='$ARG_DELETE'"
    lx output --ok "Alias '$ARG_DELETE' successfully deleted."
}

# ==============================================================================
# --- function _action_edit ---
# @desc_short       : Edits an existing command alias in cmds.db.
# ==============================================================================
function _action_edit {
    # Initialize array for the dynamic update statement
    local update_data=()
    
    # Check which edit arguments were provided and append to update data array
    if [[ -n "$ARG_EDIT_ALIAS" ]]; then
        update_data+=("alias" "$ARG_EDIT_ALIAS")
    fi
    
    if [[ -n "$ARG_EDIT_CMD" ]]; then
        update_data+=("command" "$ARG_EDIT_CMD")
    fi
    
    if [[ -n "$ARG_EDIT_DESC" ]]; then
        update_data+=("description" "$ARG_EDIT_DESC")
    fi
    
    if [[ -n "$ARG_EDIT_DEVICES" ]]; then
        update_data+=("devices" "$ARG_EDIT_DEVICES")
    fi
    
    # If no new data was provided, abort the edit process
    if (( ${#update_data[@]} == 0 )); then
        lx output --error "No edit options provided. Use --edit_alias, --edit_cmd, --edit_desc, or --edit_devices."
        return 1
    fi
    
    lx output --info "Updating alias: $ARG_EDIT"
    lx db --file "cmds.db" --table "commands" --update --data "${update_data[@]}" --where "alias='$ARG_EDIT'"
    lx output --ok "Alias '$ARG_EDIT' successfully updated."
}

# ==============================================================================
# --- function _action_cmd ---
# @desc_short       : Executes a direct command and optionally saves it as an alias.
# @parameter        : $1 | type | The type of the device (host, observer, container, vm).
# @parameter        : $2 | id   | The ID or name of the target device.
# ==============================================================================
function _action_cmd {
    local type="$1"
    local id="$2"
    
    # Check if the user requested to save the command
    if [[ -n "$ARG_SAVE" ]]; then
        local desc="${ARG_DESC:-}"
        local devices_str=""
        
        # If devices are specified via --multi, they populate an array ARG_DEVICES.
        # We join them into a comma-separated string for database storage.
        if [[ -n "${ARG_DEVICES[*]:-}" ]]; then
            local IFS=","
            devices_str="${ARG_DEVICES[*]}"
        fi
        
        # Ensure the table exists before attempting to insert
        lx db --file "cmds.db" --table "commands" --create-table \
            --cols "id INTEGER PRIMARY KEY, alias TEXT NOT NULL, description TEXT, command TEXT, devices TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP"
            
        # Insert the new command alias into the database
        lx db --file "cmds.db" --table "commands" --insert \
            --data "alias" "$ARG_SAVE" "description" "$desc" "command" "$ARG_CMD" "devices" "$devices_str"
            
        lx output --ok "Command saved as alias '$ARG_SAVE'."
    fi
    
    # Execute the command only if the --run flag is active
    if (( ARG_RUN )); then
        _execute_ssh "$type" "$id" "$ARG_CMD"
    else
        lx output --info "Command not executed. Use the --run flag to execute it immediately."
    fi
}

# ==============================================================================
# --- function _action_alias ---
# @desc_short       : Executes a saved command alias from the database.
# @parameter        : $1 | type | The type of the device (host, observer, container, vm).
# @parameter        : $2 | id   | The ID or name of the target device.
# ==============================================================================
function _action_alias {
    local type="$1"
    local id="$2"
    
    # Fetch the raw command string associated with the alias from cmds.db
    declare -a result
    lx db --file "cmds.db" --table "commands" --select @result --cols "command" --where "alias='$ARG_ALIAS'" --limit 1
    
    local cmd_string="${result[0]:-}"
    
    if [[ -z "$cmd_string" ]]; then
        lx output --error "Alias '$ARG_ALIAS' not found in cmds.db."
        return 1
    fi
    
    lx output --info "Executing alias '$ARG_ALIAS'..."
    _execute_ssh "$type" "$id" "$cmd_string"
}

# ==============================================================================
# --- function _execute_ssh ---
# @desc_short       : Helper to route and execute the actual shell command via SSH.
# @parameter        : $1 | type | The type of the device.
# @parameter        : $2 | id   | The ID or name of the device.
# @parameter        : $3 | cmd  | The exact command string to execute.
# ==============================================================================
function _execute_ssh {
    local type="$1"
    local id="$2"
    local cmd="$3"
    
    lx output --info "Target : [$type] $id"
    lx output --info "Command: $cmd"
    
    # --------------------------------------------------------------------------
    # Placeholder: Implement actual SSH, qm guest exec, or pct exec routing here.
    # Depending on 'type', route the command through the observer or run directly.
    # --------------------------------------------------------------------------
    
    lx output --ok "Execution simulation finished."
}
