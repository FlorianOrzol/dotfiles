#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Deletes a saved command entry from the commands database.
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
    # Validate required arguments
    [[ -z "$ARG_ALIAS" ]]  && { ERROR "No alias specified.";  return 1; }
    [[ -z "$ARG_DEVICE" ]] && { ERROR "No device specified."; return 1; }

    action_delete
}

# ==============================================================================
# --- action_delete ---
# @desc_short  : Deletes the entry matching alias + device; warns if not found.
# @usage       : action_delete
# ==============================================================================
function action_delete {
    local alias="$ARG_ALIAS"
    local device="$ARG_DEVICE"

    # Check if entry exists before attempting delete
    local existing
    lx db --file "$DB_FILE" --table "$DB_TABLE" --select @existing \
        --cols "id" --where "alias='${alias}' AND device='${device}'" --limit 1

    # Abort if no matching entry found
    if [[ -z "$existing" ]]; then
        WARN "No entry found for alias '${alias}' on device '${device}'."
        return 1
    fi

    lx db --file "$DB_FILE" --table "$DB_TABLE" --delete \
        --where "alias='${alias}' AND device='${device}'"

    OK "Deleted '${alias}' for '${device}'."
}
