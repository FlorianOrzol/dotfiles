#!/bin/bash
# ==============================================================================
# @meta_name        : setup/host/arguments.sh
# @desc_short       : Argumente für Host-Einrichtung und Initialisierung.
# ==============================================================================

# ==============================================================================
# --- function arguments ---
# @desc_short       : Registers all arguments for host setup.
# @usage            : lpex homelab setup host <id> [action] [options]
#
# @direct           : <id>   Host-ID aus homelab_conf.db
# @actions          : --init
# @options          : --force
# ==============================================================================
function arguments {
    # 1. --- Host ID (positional) ---------------
    arg_direct @host --description "Host-ID (z.B. 1 für host_1)" --fzf \
        --option-cmd "lx db --file 'homelab_conf.db' --table 'hosts' --select --cols 'id,name' --sep ' # ' 2>/dev/null"

    # 2. --- Actions ---------------
    arg_flag @init --description "Host initialisieren (SSH-Key, Verzeichnisse, Scripts, generate-units)"

    # 3. --- Options ---------------
    arg_flag @force --description "Idempotenz-Checks überspringen — alles neu setzen"
}
