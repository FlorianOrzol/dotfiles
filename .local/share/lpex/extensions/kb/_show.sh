#!/bin/bash
# ==============================================================================
# @meta_name        : _show.sh
# @desc_short       : Shows one entry rendered in glow's pager.
# ==============================================================================

# --- _kb_action_show ---
# @desc_short       : Shows an entry; unknown names get similar ones as hint.
# @usage            : _kb_action_show <name>
# ================================================================================
function _kb_action_show {
    local name_entry
    name_entry="$(kb_normalize "$1")"

    _kb_require_entry "$name_entry" || return 1
    kb_view "$name_entry"
}
