#!/bin/bash
# ==============================================================================
# @meta_module      : server init
# @meta_file        : arguments.sh
# @meta_date        : 2026-04-13
#
# @desc_short       : Declares CLI arguments for 'server init'.
#
# @arg_values       : --node  | Target node(s) to initialize, repeatable
# @arg_flags        : --force | Bypass idempotency checks (e.g. after hardware replacement)
#
# @notes            : --force re-runs ssh-copy-id and re-sets observer_leader even
# @notes            :   if both are already present. All other steps (push, mkdir,
# @notes            :   systemctl enable) are inherently idempotent and always run.
# ==============================================================================

function arguments() {
    arg_value @node --multi \
        --description "Target node(s) to initialize" \
        --option "pi1" --option "pi2" \
        --option "pve101" --option "pve102" --option "pve103"

    arg_flag @force \
        --description "Bypass idempotency checks — use after hardware replacement"
}
