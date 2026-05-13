#!/bin/bash
# ==============================================================================
# @meta_name        : config/list/main.sh
# @desc_short       : List all key-value entries from homelab_conf.db, grouped by section.
# ==============================================================================
source "${PATH_EXTENSION_SOURCE}/${NAME_EXTENSION}/config/extension_global.sh"

function extension_start {
    _config_init_db   # ensure settings table exists before querying

    local filter="${ARG_FILTER//\'/\'\'}"                    # escape filter for SQL LIKE clause
    local db_path="${PATH_EXTENSION_DATA}/homelab_conf.db"  # absolute path for sqlite3

    # Fetch all distinct section labels in alphabetical order
    local -a sections=()
    readarray -t sections < <(sqlite3 "$db_path" \
        "SELECT DISTINCT section FROM settings ORDER BY section;" 2>/dev/null)

    if (( ${#sections[@]} == 0 )); then
        WARN "DB is empty — add entries with 'config add'."
        return 0
    fi

    local found=0
    for section in "${sections[@]}"; do
        local esc_section="${section//\'/\'\'}"              # escape section name for SQL
        local where_clause="section='${esc_section}'"       # base WHERE: match section
        [[ -n "$filter" ]] && \
            where_clause="key LIKE '%${filter}%' AND section='${esc_section}'"  # add key filter if set

        local rows
        lx db --file "homelab_conf.db" --table "settings" --select @rows \
            --cols "key,value" --where "$where_clause" \
            --sort "key ASC" --sep " = " 2>/dev/null

        [[ -z "$rows" ]] && continue                        # skip sections with no matching entries
        found=1
        [[ -n "$section" ]] && printf "\n# --- %s ---\n" "$section"  # section header for non-empty label
        printf "%s\n" "$rows"
    done

    # Inform user when filter returned no results
    (( found == 0 )) && WARN "No entries found${filter:+ matching '${ARG_FILTER}'}."
    return 0
}
