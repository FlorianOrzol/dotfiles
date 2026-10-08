#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Removes a device from the inventory after confirmation.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Shows the device, asks, deletes the row.
# ==============================================================================
function extension_start {
    # Device is required — fzf already offered the list
    if [[ -z "$ARG_DEVICE" ]]; then
        ERROR "No device specified."
        return 1
    fi

    # Loads DEV_* from the inventory
    shelly_resolve "$ARG_DEVICE" || return 1

    INFO "${DEV_ID} — ${DEV_NAME:-?} · $(shelly_model_text "$DEV_MODEL") · ${DEV_IP} · ${DEV_MAC}"

    # Default No — room, notes and profile of the row are lost
    question "Remove '${DEV_ID}' from the inventory?" --default-no || return 1

    # Delete by MAC — the hardware identity
    lx db --file "$FILE_SHELLY_DB" --table "$TABLE_SHELLY" --delete --where "mac='${DEV_MAC}'"

    OK "Removed ${DEV_ID} — the device is untouched, 'lpex shelly scan --add' finds it again."
}
