#!/bin/bash
# ==============================================================================
# @meta_name        : variables.sh
# @desc_short       : Loads config.conf (= homelab.conf) for all submodules.
#                     Sourced automatically by LPEX before arguments() and
#                     extension_start() for every homelab submodule.
# ==============================================================================

# Load homelab.conf — defines all IPs, paths, SSH users, and helper functions
_CONFIG_FILE="${PATH_EXTENSION_DATA}/config.conf"
if [[ -f "$_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$_CONFIG_FILE"
fi

# Convenience alias for the extension data directory
PATH_HOMELAB_DATA="${PATH_EXTENSION_DATA}"
