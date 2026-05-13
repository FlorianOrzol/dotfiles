#!/bin/bash
# ==============================================================================
# @meta_name        : setup/observer/arguments.sh
# @desc_short       : Argumente für Observer-Einrichtung und Initialisierung.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for observer setup.
# @usage            : lpex homelab setup observer <id> [action] [options]
#
# @direct           : <id>   Observer-ID aus homelab_conf.db
# @actions          : --init
# @options          : --force
# ==============================================================================
function arguments {
    # 1. --- Observer ID (positional) ---------------
    arg_direct @observer --description "Observer-ID (z.B. 1 für observer_1)" --fzf \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'observers' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    # 2. --- Actions ---------------
    arg_flag @init --description "Observer initialisieren (SSH-Key, Verzeichnisse, Scripts, Units, Flags)"

    # 3. --- Options ---------------
    arg_flag @force --description "Idempotenz-Checks überspringen — alles neu setzen"
}
