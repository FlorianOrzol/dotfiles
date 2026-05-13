#!/bin/bash
# ==============================================================================
# @meta_name        : config/edit/main.sh
# @desc_short       : Update an existing key-value entry in homelab_conf.db.
# ==============================================================================
source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

function extension_start {
    _config_init_db   # ensure settings table exists before any read or write

    # Require both key and new value to proceed
    if [[ -z "${ARG_KEY:-}" || -z "${ARG_NEW_VALUE:-}" ]]; then
        ERROR "--key and --new-value are required."
        return 1
    fi

    # Refuse to edit a key that does not exist — use 'config add' instead
    if ! _config_key_exists "$ARG_KEY"; then
        ERROR "Key '${ARG_KEY}' not found in DB. Use 'config add' to create it."
        return 1
    fi

    _config_set_value "$ARG_KEY" "$ARG_NEW_VALUE"   # update value in settings table
    OK "Updated: ${ARG_KEY} = ${ARG_NEW_VALUE}"
}
