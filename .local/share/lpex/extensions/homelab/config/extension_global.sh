#!/bin/bash
# ==============================================================================
# @meta_name        : config/extension_global.sh
# @desc_short       : Shared DB helper functions for all config submodules.
#                     Sourced upward by the completion engine (Fish completion).
#                     Explicitly sourced in each config/*/main.sh for execution.
# ==============================================================================

# ==============================================================================
# --- _config_init_db ---
# @desc_short   : Creates the settings table if not yet present.
#                 Safe to call multiple times (CREATE TABLE IF NOT EXISTS).
# ==============================================================================
function _config_init_db {
    # Single flat key/value table — all config entries live here
    lx db --file "homelab_conf.db" --table "settings" --create-table \
        --cols "key TEXT PRIMARY KEY, value TEXT NOT NULL"
}

# ==============================================================================
# --- _config_key_exists ---
# @desc_short   : Returns 0 if the given key exists in settings, 1 if not.
# @parameter    : $1 | key | Config key to check
# ==============================================================================
function _config_key_exists {
    local key="$1"
    local esc_key="${key//\'/\'\'}"    # escape single quotes for SQL
    local -a result=()
    lx db --file "homelab_conf.db" --table "settings" --select @result \
        --cols "key" --where "key='${esc_key}'" --limit 1 2>/dev/null
    [[ -n "${result[0]:-}" ]]          # non-empty result → key found → return 0
}

# ==============================================================================
# --- _config_set_value ---
# @desc_short   : Upserts a key-value pair into the settings table.
# @parameter    : $1 | key   | Config key
# @parameter    : $2 | value | New value to store
# ==============================================================================
function _config_set_value {
    local key="$1" value="$2"
    local esc_key="${key//\'/\'\'}"    # escape key for SQL
    local esc_val="${value//\'/\'\'}"  # escape value for SQL
    lx db --file "homelab_conf.db" --exec \
        "INSERT OR REPLACE INTO settings(key,value) VALUES('${esc_key}','${esc_val}');"
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
    local -a result=()
    lx db --file "homelab_conf.db" --table "settings" --select @result \
        --cols "value" --where "key='${esc_key}'" --limit 1 2>/dev/null
    echo "${result[0]:-}"             # print found value, or empty string if missing
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
