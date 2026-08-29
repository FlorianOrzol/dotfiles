#!/bin/bash
# ==============================================================================
# @meta_name        : arguments.sh
# @desc_short       : CLI argument definitions for 'ha' (HA list & boot order).
# ==============================================================================

# --- function arguments ---
# @desc_short       : Registers CLI arguments for HA client list management.
# @usage            : lpex homelab ha [action]
#
# @actions          : (none)            → show HA list in boot order
#                     --add <id>        → append container to HA (end of boot order)
#                     --remove <id>     → remove container from HA
#                     --move <id> --to <pos> → reposition container in the boot order
#                     --edit            → edit the full boot order list in $EDITOR
#
# @options          : --reason <text>   → recorded with the removal (only with --remove)
# ==============================================================================
function arguments {
    arg_value @add    --description "Container ID to add to HA (appended to boot order)"  --fzf --option-cmd "get_containers"
    arg_value @remove --description "Container ID to remove from HA"                      --fzf --option-cmd "get_ha_clients"
    arg_value @move   --description "Container ID to reposition in the boot order"        --fzf --option-cmd "get_ha_clients"
    arg_value @to     --description "Target boot position (1-based)" --depends-on "ARG_MOVE"
    arg_value @reason --description "Why the container leaves HA (kept in the status view)" --depends-on "ARG_REMOVE"
    arg_flag  @edit   --description "Edit the boot order list in \$EDITOR"
}
