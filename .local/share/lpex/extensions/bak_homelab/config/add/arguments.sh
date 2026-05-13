#!/bin/bash
# ==============================================================================
# @meta_name        : config/add/arguments.sh
# @desc_short       : CLI arguments for adding a new config key.
# ==============================================================================

# --- function arguments ---
# @desc_short   : Registers CLI arguments for config add.
# @usage        : lpex homelab config add --key <key> --value <value> [--section <section>]
#
# @options      : --key     | New config key (e.g. IP_HOST_3, SSH_USER_OBSERVER)
#                 --value   | Value to store for that key
#                 --section | Section label for grouping in homelab.conf (e.g. Hosts, ZFS Pools)
# ==============================================================================
function arguments {
    arg_value @key     --description "New config key (e.g. IP_HOST_3, SSH_USER_OBSERVER)"
    arg_value @value   --description "Value for the new key"
    arg_value @section --description "Section label for grouping in homelab.conf (e.g. Hosts, ZFS Pools)"
}
