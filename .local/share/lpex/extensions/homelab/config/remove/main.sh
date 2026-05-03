#!/bin/bash
# ==============================================================================
# @meta_name        : config/remove/main.sh
# @desc_short       : Konfigurationseintrag aus homelab_conf.db löschen.
# ==============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../_helpers.sh"

function extension_start {
    _config_init_db

    if [[ -z "${ARG_KEY:-}" ]]; then
        ERROR "Schlüssel (--key) ist erforderlich."
        return 1
    fi

    if ! _config_key_exists "$ARG_KEY"; then
        ERROR "Schlüssel '${ARG_KEY}' nicht in DB."
        return 1
    fi

    _config_parse_key "$ARG_KEY"

    # Warnung: bei strukturierten Keys wird die ganze Zeile gelöscht
    if (( _CKEY_IS_STRUCT == 1 )); then
        WARN "Strukturierter Eintrag: Löscht den kompletten DB-Eintrag in '${_CKEY_TABLE}' (id=${_CKEY_ID})."
        WARN "Alle Felder dieses Eintrags (IP, Name, MAC) werden entfernt."
    fi

    question "Eintrag '${ARG_KEY}' wirklich löschen?" --default-no || return 0

    _config_delete_key "$ARG_KEY"
    OK "Eintrag '${ARG_KEY}' gelöscht."
}
