#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Edits a saved shortcut — via options or in $EDITOR.
# ==============================================================================

# Action file — LPEX does not auto-load _*.sh, always via $PATH_EXTENSION
source "${PATH_EXTENSION}/_edit.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Loads the shortcut, collects the changes and stores them.
# ==============================================================================
function extension_start {
    # Alias is required — fzf already offered the list
    if [[ -z "$ARG_ALIAS" ]]; then
        ERROR "No alias specified."
        return 1
    fi

    # Loads CMD_ID, CMD_CMD, CMD_DEVICES, CMD_DESCRIPTION
    cmd_read_alias "$ARG_ALIAS" || return 1

    # Start from the stored values — every path below only overrides
    _edit_load_current

    # Options given → apply them; none → open the whole entry in the editor
    if [[ -n "$ARG_NEW_ALIAS" || -n "${ARG_CMD[*]}" || -n "$ARG_DESCRIPTION" \
          || ${#ARG_ADD_DEVICE[@]} -gt 0 || ${#ARG_REMOVE_DEVICE[@]} -gt 0 ]]; then
        _edit_apply_options || return 1
    else
        _edit_in_editor || return 1
    fi

    _edit_store
}
