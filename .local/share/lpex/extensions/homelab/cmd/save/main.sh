#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Saves a command entry to the commands database.
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
    # Ensure table exists (UNIQUE constraint enforced on alias + device)
    lx db --file "$DB_FILE" --table "$DB_TABLE" --create-table \
        --cols "id INTEGER PRIMARY KEY, alias TEXT NOT NULL, cmd TEXT NOT NULL, device TEXT NOT NULL, description TEXT, UNIQUE(alias, device)"

    # Validate required arguments
    [[ -z "$ARG_ALIAS" ]]         && { ERROR "No alias specified.";   return 1; }
    [[ -z "$ARG_CMD" ]]           && { ERROR "No command specified."; return 1; }
    [[ ${#ARG_DEVICE[@]} -eq 0 ]] && { ERROR "No device specified.";  return 1; }

    action_save
}

# ==============================================================================
# --- action_save ---
# @desc_short  : Inserts one row per selected device; skips duplicate alias/device pairs.
# @usage       : action_save
# ==============================================================================
function action_save {
    local alias="$ARG_ALIAS"
    local cmd="$ARG_CMD"
    local description="${ARG_DESCRIPTION:-}"    # empty string when not provided

    # Insert one entry per selected device
    for device in "${ARG_DEVICE[@]}"; do

        # Check if alias already exists for this device
        local existing
        lx db --file "$DB_FILE" --table "$DB_TABLE" --select @existing \
            --cols "id" --where "alias='${alias}' AND device='${device}'" --limit 1

        # Skip if duplicate found
        if [[ -n "$existing" ]]; then
            WARN "Alias '${alias}' already exists for '${device}' — skipped."
            continue
        fi

        lx db --file "$DB_FILE" --table "$DB_TABLE" --insert \
            --data "alias" "$alias" "cmd" "$cmd" "device" "$device" "description" "$description"

        OK "Saved '${alias}' for '${device}'."
    done
}
