#!/bin/bash
# ==============================================================================
# @meta_name        : config/edit/main.sh
# @desc_short       : Bestehenden Konfigurationseintrag in homelab_conf.db ändern.
# ==============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../_helpers.sh"

function extension_start {
    _config_init_db

    if [[ -z "${ARG_KEY:-}" || -z "${ARG_NEW_VALUE:-}" ]]; then
        ERROR "Schlüssel (--key) und neuer Wert (--new-value) sind erforderlich."
        return 1
    fi

    if ! _config_key_exists "$ARG_KEY"; then
        ERROR "Schlüssel '${ARG_KEY}' nicht in DB. Verwende 'config add' zum Hinzufügen."
        return 1
    fi

    _config_set_value "$ARG_KEY" "$ARG_NEW_VALUE"
    OK "Aktualisiert: ${ARG_KEY} = ${ARG_NEW_VALUE}"
}
