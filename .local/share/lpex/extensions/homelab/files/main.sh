#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Entry point for 'homelab files' — validates that exactly one
#                     action is selected and routes to the matching action file.
#                     Action files (_push.sh, _fetch.sh, ...) are sourced lazily:
#                     only the file of the selected action is loaded.
# ==============================================================================

# Shared mirror-path helpers are needed by every action — sourced unconditionally.
source "${PATH_EXTENSION}/_common.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Validates the action selection, sources the selected action file
#                and delegates to its entry function.
# ==============================================================================
function extension_start {
    # 1. --- Routing ----------------------------------------------------------

    # Push: source the push logic and push each requested device mirror.
    if (( ${#ARG_PUSH[@]} )); then
        source "${PATH_EXTENSION}/_push.sh"
        action_push_devices "${ARG_PUSH[@]}"
        return
    fi

    # Fetch: source the fetch logic — device and base path come from ARG_* globals.
    if [[ -n "$ARG_FETCH" ]]; then
        source "${PATH_EXTENSION}/_fetch.sh"
        action_fetch
        return
    fi

    # Delete: source the delete logic and delete each requested mirror path.
    if (( ${#ARG_DELETE[@]} )); then
        source "${PATH_EXTENSION}/_delete.sh"
        action_delete_paths "${ARG_DELETE[@]}"
        return
    fi

    # Rename: source the rename logic — the new name comes from ARG_RENAME_TO.
    if [[ -n "$ARG_RENAME" ]]; then
        source "${PATH_EXTENSION}/_rename.sh"
        action_rename_entry "$ARG_RENAME"
        return
    fi

    # Goto: source the goto logic and open the mirror directory in the terminal.
    if [[ -n "$ARG_GOTO" ]]; then
        source "${PATH_EXTENSION}/_goto.sh"
        action_goto "$ARG_GOTO"
        return
    fi

    # No action matched — nothing was routed.
    ERROR "No action specified. Use --push, --fetch, --delete, --rename, or --goto."
    return 1
}
