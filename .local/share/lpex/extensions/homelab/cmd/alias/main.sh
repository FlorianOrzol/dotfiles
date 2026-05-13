#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Executes a saved command alias on its associated device.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
DB_FILE="cmds.db"       # database file, resolved relative to PATH_EXTENSION_DATA
DB_TABLE="commands"     # table name for stored commands

# ==============================================================================
# --- extension_start ---
# ==============================================================================
function extension_start {
    # Validate that an alias was provided
    [[ -z "$ARG_ALIAS" ]]  && { ERROR "No alias specified.";  return 1; }
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No device specified."; return 1; }

    action_run_alias
}

# ==============================================================================
# --- action_run_alias ---
# @desc_short  : Looks up the stored command for alias + device and executes it remotely.
# @usage       : action_run_alias
# ==============================================================================
function action_run_alias {
    local alias="$ARG_ALIAS"
    local device="$ARG_DEVICE"

    # Fetch stored command for this alias and device combination
    local stored_cmd
    lx db --file "$DB_FILE" --table "$DB_TABLE" --select @stored_cmd \
        --cols "cmd" --where "alias='${alias}' AND device='${device}'" --limit 1

    # Abort if no matching entry found
    if [[ -z "$stored_cmd" ]]; then
        ERROR "No entry found for alias '${alias}' on device '${device}'."
        return 1
    fi

    INFO "Running alias '${alias}' on '${device}'..."
    execute_on_device "$device" "$stored_cmd"
}
