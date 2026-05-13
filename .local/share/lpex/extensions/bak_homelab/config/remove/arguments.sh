#!/bin/bash
# ==============================================================================
# @meta_name        : config/remove/arguments.sh
# @desc_short       : CLI arguments for removing a config key.
# ==============================================================================

# --- function arguments ---
# @desc_short   : Registers CLI arguments for config remove.
# @usage        : lpex homelab config remove <key>
#
# @direct       : <key> | Existing config key to remove (FZF from DB)
# ==============================================================================
function arguments {
    local keys  # all entries for FZF

    # Load all keys as "KEY # value" multiline string — scalar receives full output directly
    lx db --file "homelab_conf.db" --table "settings" --select @keys \
        --cols "key,value" --sep " # " --sort "key ASC" 2>/dev/null

    arg_direct @key --description "Config key to remove" --fzf \
        --option-cmd "echo '${keys}'"
}
