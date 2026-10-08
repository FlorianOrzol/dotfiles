#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Edits inventory data of one device.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the changes and writes them in one update.
# ==============================================================================
function extension_start {
    local -a data=()
    local id_new

    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Loads DEV_* from the inventory
    shelly_resolve "$ARG_DEVICE" || return 1

    # A new id must be a valid slug and free
    if [[ -n "$ARG_ID" ]]; then
        if [[ ! "$ARG_ID" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            ERROR "Invalid id '${ARG_ID}' — lowercase a-z, 0-9 and single '-' (e.g. ventil-flur-oben)."
            return 1
        fi
        id_new=$(shelly_unique_id "$ARG_ID" "$DEV_MAC")
        if [[ "$id_new" != "$ARG_ID" ]]; then
            ERROR "id '${ARG_ID}' is taken — e.g. '${id_new}' would be free."
            return 1
        fi
        data+=("id" "$ARG_ID")
    fi

    # Collect the remaining fields that were given
    [[ -n "$ARG_NAME" ]]    && data+=("name" "$ARG_NAME")
    [[ -n "$ARG_ROOM" ]]    && data+=("room" "$ARG_ROOM")
    [[ -n "$ARG_PROFILE" ]] && data+=("profile" "$ARG_PROFILE")
    [[ -n "$ARG_NOTES" ]]   && data+=("notes" "$ARG_NOTES")

    # Nothing to change is most likely a forgotten option
    if (( ${#data[@]} == 0 )); then
        ERROR "Nothing to change — use --id, --name, --room, --profile or --notes."
        return 1
    fi

    # One update by MAC — the id itself may be part of the change
    if ! lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --update --where "mac='${DEV_MAC}'" --data "${data[@]}"; then
        ERROR "Update of '${DEV_ID}' failed."
        return 1
    fi

    OK "Updated ${ARG_ID:-$DEV_ID}."

    # Name and id live in the inventory only until 'config' writes them to the device
    if [[ -n "$ARG_NAME" || -n "$ARG_ID" ]]; then
        INFO "The device itself still has its old name — writing it comes with 'lpex shelly config' (phase 3)."
    fi
}
