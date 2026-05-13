#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Lists saved command entries from the commands database.
# ==============================================================================

# ==============================================================================
# --- Script Internals ---
# ==============================================================================
DB_FILE="cmds.db"       # database file, resolved relative to PATH_EXTENSION_DATA
DB_TABLE="commands"     # table name for stored commands

# ==============================================================================
# --- extension_start ---
# ==============================================================================
function extension_start {
    action_list
}

# ==============================================================================
# --- action_list ---
# @desc_short  : Queries the DB with optional filters and prints a formatted table.
# @usage       : action_list
# ==============================================================================
function action_list {
    local where=""

    # Build WHERE clause from provided filters
    [[ -n "$ARG_DEVICE" ]] && where="device='${ARG_DEVICE}'"
    [[ -n "$ARG_ALIAS" ]]  && where="${where:+${where} AND }alias='${ARG_ALIAS}'"

    # Run query — lx db without @var prints a formatted table to stdout
    if [[ -n "$where" ]]; then
        lx db --file "$DB_FILE" --table "$DB_TABLE" --select --where "$where" \
            --sort "device ASC, alias ASC"
    else
        lx db --file "$DB_FILE" --table "$DB_TABLE" --select \
            --sort "device ASC, alias ASC"
    fi
}
