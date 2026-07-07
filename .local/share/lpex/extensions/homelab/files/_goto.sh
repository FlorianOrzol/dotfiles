#!/bin/bash
# ==============================================================================
# @meta_name        : _goto.sh
# @desc_short       : Open a local mirror directory in the configured terminal.
#                     Sourced lazily by files/main.sh when --goto is used.
# ==============================================================================

# ==============================================================================
# --- action_goto ---
# @desc_short  : Entry function for --goto. Validates the mirror directory and
#                opens it in the configured terminal.
# @usage       : action_goto <mirror_dir>
# @parameter   : $1 | mirror_dir | Local mirror base directory to open
# ==============================================================================
function action_goto {
    local mirror_dir="$1"

    # Directory must exist locally — run fetch first if not yet populated.
    if [[ ! -d "$mirror_dir" ]]; then
        WARN "Mirror directory does not exist: ${mirror_dir}"
        INFO "Run 'lpex homelab files --fetch <device>' first to populate the mirror."
        return 1
    fi

    INFO "Opening mirror: ${mirror_dir}"

    # Open in background so the terminal launch does not block the shell.
    $TERMINAL "$mirror_dir" &
}
