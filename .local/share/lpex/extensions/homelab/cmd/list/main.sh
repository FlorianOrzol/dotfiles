#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Lists saved shortcuts as a table.
# ==============================================================================

# ==============================================================================
# --- extension_start ---
# @desc_short  : Prints all shortcuts, optionally only those of one device.
# ==============================================================================
function extension_start {
    local where="1=1"                   # no filter: every row

    # Nothing saved yet — say so instead of printing an empty table
    if [[ ! -f "$FILE_CMDS_DB" ]]; then
        INFO "No saved commands yet — 'lpex homelab cmd save' or 'cmd run --save'."
        return 0
    fi

    # devices is space-separated: pad with spaces so 'ct_30' never matches 'ct_3040'
    if [[ -n "$ARG_DEVICE" ]]; then
        where="(' ' || devices || ' ') LIKE '% ${ARG_DEVICE} %'"
    fi

    # Without @var lx db prints a formatted table to stdout
    lx db --file "$FILE_CMDS_DB" --table "$TABLE_CMDS" --select \
        --cols "alias,devices,cmd,description" --where "$where" --sort "alias ASC"
}
