#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Deletes a saved shortcut after confirmation.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Shows the shortcut, asks, deletes it.
# ==============================================================================
function extension_start {
    # Alias is required — fzf already offered the list
    if [[ -z "$ARG_ALIAS" ]]; then
        ERROR "No alias specified."
        return 1
    fi

    # Loads CMD_ID, CMD_CMD, CMD_DEVICES, CMD_DESCRIPTION
    cmd_read_alias "$ARG_ALIAS" || return 1

    INFO "${ARG_ALIAS} (${CMD_DEVICES}): ${CMD_CMD}"

    # Default No — a deleted shortcut is gone, there is no undo
    question "Delete '${ARG_ALIAS}'?" --default-no || return 1

    # Delete by id — the alias was resolved above
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --delete --where "id=${CMD_ID}"

    OK "Deleted '${ARG_ALIAS}'."
}
