#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Edits a saved command entry in the commands database.
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
    # Validate that an alias was selected
    [[ -z "$ARG_ALIAS" ]] && { ERROR "No alias specified."; return 1; }

    # Require at least one edit operation
    if [[ -z "$ARG_NEW_ALIAS" && -z "$ARG_CMD" && -z "$ARG_DESCRIPTION" \
          && ${#ARG_ADD_DEVICE[@]} -eq 0 && ${#ARG_REMOVE_DEVICE[@]} -eq 0 ]]; then
        ERROR "Nothing to edit. Specify --new-alias, --cmd, --description, --add-device or --remove-device."
        return 1
    fi

    action_edit
}

# ==============================================================================
# --- action_edit ---
# @desc_short  : Routes to individual edit operations based on provided arguments.
# @usage       : action_edit
# ==============================================================================
function action_edit {
    # Update scalar fields if provided (applies to all rows with this alias)
    [[ -n "$ARG_NEW_ALIAS" ]]           && action_update_field "alias"       "$ARG_NEW_ALIAS"
    [[ -n "$ARG_CMD" ]]                 && action_update_field "cmd"         "$ARG_CMD"
    [[ -n "$ARG_DESCRIPTION" ]]         && action_update_field "description" "$ARG_DESCRIPTION"

    # Handle device additions and removals
    [[ ${#ARG_ADD_DEVICE[@]} -gt 0 ]]    && action_add_devices
    [[ ${#ARG_REMOVE_DEVICE[@]} -gt 0 ]] && action_remove_devices
}

# ==============================================================================
# --- action_update_field ---
# @desc_short  : Updates a single field across all rows sharing the current alias.
# @usage       : action_update_field <field> <value>
# @parameter   : $1 | field | Column name to update.
# @parameter   : $2 | value | New value for the column.
# ==============================================================================
function action_update_field {
    local field="$1"
    local value="$2"
    local alias="$ARG_ALIAS"

    lx db --file "$DB_FILE" --table "$DB_TABLE" --update \
        --data "$field" "$value" --where "alias='${alias}'"

    OK "Updated ${field} for '${alias}'."

    # Track renamed alias so subsequent operations still find the rows
    [[ "$field" == "alias" ]] && ARG_ALIAS="$value"
}

# ==============================================================================
# --- action_add_devices ---
# @desc_short  : Copies the current entry to one or more additional devices.
# @usage       : action_add_devices
# ==============================================================================
function action_add_devices {
    local alias="$ARG_ALIAS"

    # Fetch current cmd and description to copy into new entries
    local current_cmd current_description
    lx db --file "$DB_FILE" --table "$DB_TABLE" --select @current_cmd \
        --cols "cmd" --where "alias='${alias}'" --limit 1
    lx db --file "$DB_FILE" --table "$DB_TABLE" --select @current_description \
        --cols "description" --where "alias='${alias}'" --limit 1

    for device in "${ARG_ADD_DEVICE[@]}"; do
        # Skip if alias already exists for this device
        local existing
        lx db --file "$DB_FILE" --table "$DB_TABLE" --select @existing \
            --cols "id" --where "alias='${alias}' AND device='${device}'" --limit 1

        if [[ -n "$existing" ]]; then
            WARN "Alias '${alias}' already exists for '${device}' — skipped."
            continue
        fi

        lx db --file "$DB_FILE" --table "$DB_TABLE" --insert \
            --data "alias" "$alias" "cmd" "$current_cmd" "device" "$device" \
                   "description" "$current_description"

        OK "Added '${alias}' for '${device}'."
    done
}

# ==============================================================================
# --- action_remove_devices ---
# @desc_short  : Removes the entry for one or more devices; last device cannot be removed.
# @usage       : action_remove_devices
# ==============================================================================
function action_remove_devices {
    local alias="$ARG_ALIAS"

    # Fetch all current devices for this alias to enforce minimum-one constraint
    declare -a current_devices
    lx db --file "$DB_FILE" --table "$DB_TABLE" --select @current_devices \
        --cols "device" --where "alias='${alias}'"

    local total_count=${#current_devices[@]}
    local remove_count=${#ARG_REMOVE_DEVICE[@]}

    # Abort if removal would leave no entries
    if (( total_count - remove_count < 1 )); then
        ERROR "Cannot remove all devices — at least one entry must remain for '${alias}'."
        return 1
    fi

    for device in "${ARG_REMOVE_DEVICE[@]}"; do
        lx db --file "$DB_FILE" --table "$DB_TABLE" --delete \
            --where "alias='${alias}' AND device='${device}'"

        OK "Removed '${alias}' from '${device}'."
    done
}
