#!/bin/bash
# ==============================================================================
# @meta_name        : config/remove/main.sh
# @desc_short       : Delete a key-value entry from homelab_conf.db.
# ==============================================================================
source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

function extension_start {
    _config_init_db   # ensure settings table exists before any read or write

    # Key argument is mandatory for delete
    if [[ -z "${ARG_KEY:-}" ]]; then
        ERROR "--key is required."
        return 1
    fi

    # Refuse to delete a key that does not exist in the DB
    if ! _config_key_exists "$ARG_KEY"; then
        ERROR "Key '${ARG_KEY}' not found in DB."
        return 1
    fi

    # Ask for confirmation before permanently deleting — default is no
    question "Really delete '${ARG_KEY}'?" --default-no || return 0

    _config_delete_key "$ARG_KEY"   # delete key from settings table
    OK "Entry '${ARG_KEY}' deleted."
}
