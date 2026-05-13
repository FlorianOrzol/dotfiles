#!/bin/bash
# ==============================================================================
# @meta_name        : config/extension_global.sh
# @desc_short       : Shared DB helper functions for all config submodules.
#                     Sourced upward by the completion engine (Fish completion).
#                     Explicitly sourced in each config/*/main.sh for execution.
# ==============================================================================

# ==============================================================================
# --- _config_init_db ---
# @desc_short   : Creates the settings table if not yet present and migrates
#                 existing DBs by adding the section column when missing.
#                 Safe to call multiple times.
# ==============================================================================
function _config_init_db {
    # Create flat key/value/section table — all config entries live here
    lx db --file "homelab_conf.db" --table "settings" --create-table \
        --cols "key TEXT PRIMARY KEY, value TEXT NOT NULL, section TEXT NOT NULL DEFAULT ''"
    # Migrate older DBs that lack the section column — error is silently ignored if already present
    lx db --file "homelab_conf.db" --exec \
        "ALTER TABLE settings ADD COLUMN section TEXT NOT NULL DEFAULT '';" 2>/dev/null || true
}

# ==============================================================================
# --- _config_key_exists ---
# @desc_short   : Returns 0 if the given key exists in settings, 1 if not.
# @parameter    : $1 | key | Config key to check
# ==============================================================================
function _config_key_exists {
    local key="$1"
    local esc_key="${key//\'/\'\'}"    # escape single quotes for SQL
    local result                       # scalar — non-empty when key is found
    lx db --file "homelab_conf.db" --table "settings" --select @result \
        --cols "key" --where "key='${esc_key}'" --limit 1 2>/dev/null
    [[ -n "${result:-}" ]]             # non-empty result → key found → return 0
}

# ==============================================================================
# --- _config_set_value ---
# @desc_short   : Upserts a key-value pair into the settings table.
#                 When section is provided it is stored/updated alongside value.
#                 When section is omitted the existing section is preserved on update.
# @parameter    : $1 | key     | Config key
# @parameter    : $2 | value   | Value to store
# @parameter    : $3 | section | Section label (optional)
# ==============================================================================
function _config_set_value {
    local key="$1" value="$2" section="${3:-}"
    local esc_key="${key//\'/\'\'}"    # escape key for SQL
    local esc_val="${value//\'/\'\'}"  # escape value for SQL
    local esc_sec="${section//\'/\'\'}" # escape section for SQL
    if [[ -n "$section" ]]; then
        # Full upsert — section is explicitly provided, overwrite any existing row
        lx db --file "homelab_conf.db" --exec \
            "INSERT OR REPLACE INTO settings(key,value,section) VALUES('${esc_key}','${esc_val}','${esc_sec}');"
    else
        # Value-only upsert — preserve existing section on conflict (edit use-case)
        lx db --file "homelab_conf.db" --exec \
            "INSERT INTO settings(key,value,section) VALUES('${esc_key}','${esc_val}','') ON CONFLICT(key) DO UPDATE SET value='${esc_val}';"
    fi
}

# ==============================================================================
# --- _config_get_current_value ---
# @desc_short   : Returns the current value of a config key (empty if not found).
# @parameter    : $1 | key | Config key to look up
# ==============================================================================
function _config_get_current_value {
    local key="$1"
    [[ -z "$key" ]] && return          # nothing to look up if key is not set
    local esc_key="${key//\'/\'\'}"    # escape single quotes for SQL
    local result                       # scalar — receives single-row output directly
    lx db --file "homelab_conf.db" --table "settings" --select @result \
        --cols "value" --where "key='${esc_key}'" --limit 1 2>/dev/null
    echo "${result:-}"                 # print found value, or empty string if missing
}

# ==============================================================================
# --- _config_delete_key ---
# @desc_short   : Deletes a key from the settings table.
# @parameter    : $1 | key | Config key to delete
# ==============================================================================
function _config_delete_key {
    local key="$1"
    local esc_key="${key//\'/\'\'}"   # escape single quotes for SQL
    lx db --file "homelab_conf.db" --exec \
        "DELETE FROM settings WHERE key='${esc_key}';"
}
