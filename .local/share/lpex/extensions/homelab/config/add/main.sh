#!/bin/bash
# ==============================================================================
# @meta_name        : config/add/main.sh
# @desc_short       : Neuen Konfigurationseintrag in homelab_conf.db hinzufügen.
# ==============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../_helpers.sh"

function extension_start {
    _config_init_db

    if [[ -z "${ARG_KEY:-}" || -z "${ARG_VALUE:-}" ]]; then
        ERROR "Schlüssel (--key) und Wert (--value) sind erforderlich."
        return 1
    fi

    _config_parse_key "$ARG_KEY"

    # Für Settings-Einträge: Prüfen ob Key bereits existiert
    if (( _CKEY_IS_STRUCT == 0 )); then
        if _config_key_exists "$ARG_KEY"; then
            ERROR "Schlüssel '${ARG_KEY}' existiert bereits. Verwende 'config edit' zum Ändern."
            return 1
        fi
    fi

    _config_set_value "$ARG_KEY" "$ARG_VALUE"
    OK "Eintrag gesetzt: ${ARG_KEY} = ${ARG_VALUE}"
}
