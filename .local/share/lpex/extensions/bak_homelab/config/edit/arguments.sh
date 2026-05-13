#!/bin/bash
# ==============================================================================
# @meta_name        : config/edit/arguments.sh
# @desc_short       : CLI arguments for editing an existing config key.
# ==============================================================================

# --- function arguments ---
# @desc_short   : Registers CLI arguments for config edit.
# @usage        : lpex homelab config edit <key> --new-value <value>
#
# @direct       : <key>        Existing config key (FZF from DB)
# @options      : --new-value  Replacement value; description shows current value
# ==============================================================================
function arguments {
    local keys value  # keys: all entries for FZF; value: current value of selected key

    # Load all keys as "KEY # value" multiline string — scalar receives full output directly
    lx db --file "homelab_conf.db" --table "settings" --select @keys \
        --cols "key,value" --sep " # " --sort "key ASC" 2>/dev/null

    arg_direct @key --description "Config key to edit" --fzf \
        --option-cmd "echo '${keys}'"

    # Look up current value for the already-entered key via ARGS_ENTERED
    lx db --file "homelab_conf.db" --table "settings" --select @value \
        --cols "value" --where "key='${ARGS_ENTERED[0]}'" --limit 1 2>/dev/null

    arg_value @new_value --description "New value (old: ${value})"
}
