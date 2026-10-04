#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : 'kb' — routes to browser, actions or the view of an entry.
# ==============================================================================

# source action files — must be explicit, LPEX does not auto-load _*.sh
# always via $PATH_EXTENSION (official LPEX variable) — never BASH_SOURCE/dirname
source "${PATH_EXTENSION}/_browse.sh"
source "${PATH_EXTENSION}/_show.sh"
source "${PATH_EXTENSION}/_edit.sh"
source "${PATH_EXTENSION}/_rm.sh"
source "${PATH_EXTENSION}/_list.sh"

# --- extension_start ---
# @desc_short  : Routes the first position to an action or shows the named entry.
# ==============================================================================
function extension_start {
    local first="${ARG_FIRST:-}"
    local second="${ARG_SECOND:-}"
    local text_search="${ARGS_EXTENSION_ARRAY[*]:1}"   # search may span several words

    # The data zone exists from the first entry on
    mkdir -p "$PATH_KB_DATA"

    # Route by the first position — anything that is no action is an entry name
    case "$first" in
        "")     _kb_action_browse ;;
        new)    _kb_action_edit "$second" new ;;
        edit)   _kb_action_edit "$second" edit ;;
        rm)     _kb_action_rm "$second" ;;
        search) _kb_action_browse "$text_search" ;;
        list)   _kb_action_list ;;
        *)      _kb_action_show "$first" ;;
    esac
}
