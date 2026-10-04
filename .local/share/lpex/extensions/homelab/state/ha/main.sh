#!/bin/bash
# ==============================================================================
# @meta_name        : main.sh
# @desc_short       : Entry point for 'homelab state ha' — shows the HA boot
#                     order with live status and override info.
#                     Changes to the list live in 'setup ha' (add/remove/move/edit).
# ==============================================================================

# source action file — must be explicit, LPEX does not auto-load _*.sh
# always via $PATH_EXTENSION (official LPEX variable) — never BASH_SOURCE/dirname
source "${PATH_EXTENSION}/_list.sh"

# ==============================================================================
# --- extension_start ---
# @desc_short  : Prints the current HA boot order.
# ==============================================================================
function extension_start {
    action_list
}
