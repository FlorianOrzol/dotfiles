#!/bin/bash
# ==============================================================================
# @meta_name        : _rm.sh
# @desc_short       : Deletes an entry after a confirmation.
# ==============================================================================

# --- _kb_action_rm ---
# @desc_short       : Deletes an entry; an emptied topic folder goes with it.
# @usage            : _kb_action_rm <name>
# ================================================================================
function _kb_action_rm {
    local name_entry
    local file_entry
    name_entry="$(kb_normalize "$1")"

    # A name is required — deleting is never guessed
    if [[ -z "$name_entry" ]]; then
        ERROR "No entry specified. Usage: kb rm <topic/name>"
        return 1
    fi

    _kb_require_entry "$name_entry" || return 1
    file_entry="$(kb_file "$name_entry")"

    # Deleting cannot be undone locally (only via the git history of the state repo)
    if ! question "Delete '${name_entry}' ($(kb_title "$name_entry"))?" --default-no; then
        INFO "Kept."
        return 0
    fi

    rm -f "$file_entry"
    # The topic folder only exists for its entries
    rmdir --ignore-fail-on-non-empty "$(dirname "$file_entry")"
    OK "Deleted: ${name_entry}"
}
